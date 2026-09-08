// End-to-end smoke test with an in-memory MongoDB — no local Mongo install needed.
//   node src/smoke.js
// Exits non-zero on the first failed assertion.
process.env.JWT_SECRET = process.env.JWT_SECRET || 'smoke-secret';

const { MongoMemoryServer } = require('mongodb-memory-server');
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');

const { createApp } = require('./app');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const Loan = require('./models/Loan');
const Settings = require('./models/Settings');
const {
  SAMPLE,
  SAMPLE_LOANS,
  buildTxn,
  OPENING_CASH,
  OPENING_GOLD_GRAMS,
} = require('./seed');

let pass = 0;
function check(label, cond) {
  if (cond) {
    pass += 1;
    console.log(`  ok  ${label}`);
  } else {
    console.error(`FAIL  ${label}`);
    process.exitCode = 1;
    throw new Error(`assertion failed: ${label}`);
  }
}
const approx = (a, b, tol = 0.02) => Math.abs(a - b) <= tol;
const between = (x, lo, hi) => x >= lo && x <= hi;

async function main() {
  const mem = await MongoMemoryServer.create();
  await connectDb(mem.getUri('gold_manager'));

  await User.findOneAndUpdate(
    { username: 'mani' },
    { username: 'mani', passwordHash: await bcrypt.hash('1977', 10) },
    { upsert: true }
  );
  await Settings.findByIdAndUpdate(
    'app',
    { _id: 'app', openingCash: OPENING_CASH, openingGoldGrams: OPENING_GOLD_GRAMS },
    { upsert: true }
  );
  await Transaction.insertMany(SAMPLE.map(buildTxn));
  await Loan.insertMany(SAMPLE_LOANS);

  const app = createApp();
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const J = async (res) => ({ status: res.status, body: await res.json().catch(() => null) });
  const GET = (p, h) => fetch(`${base}${p}`, { headers: h }).then(J);
  const POST = (p, h, b) =>
    fetch(`${base}${p}`, { method: 'POST', headers: h, body: JSON.stringify(b) }).then(J);
  const DEL = (p, h) => fetch(`${base}${p}`, { method: 'DELETE', headers: h }).then(J);

  // --- auth ---
  let r = await POST('/api/auth/login', { 'Content-Type': 'application/json' }, {
    username: 'mani',
    password: '1977',
  });
  check('login mani/1977 -> token', r.status === 200 && typeof r.body.token === 'string');
  const H = { Authorization: `Bearer ${r.body.token}`, 'Content-Type': 'application/json' };

  r = await POST('/api/auth/login', { 'Content-Type': 'application/json' }, {
    username: 'mani',
    password: 'nope',
  });
  check('wrong password -> 401', r.status === 401);
  check('no token -> 401', (await GET('/api/stock')).status === 401);

  // --- settings / opening balances ---
  r = await GET('/api/settings', H);
  check('opening balances = ₹15,00,000 + 100 g',
    approx(r.body.openingCash, 1500000) && approx(r.body.openingGoldGrams, 100));

  // --- unified position ---
  r = await GET('/api/stock', H);
  const s = r.body;
  check('gold in stock = 90 g  (100 opening + 40 trade − 50 gold-loan)',
    approx(s.weightGrams, 90));
  check('cash in hand = ₹10,76,000', approx(s.cashInHand, 1076000, 1));
  check('avg cost ≈ ₹5,970.83 /g', approx(s.avgCostPerGram, 5970.83, 0.1));
  check('trade realized profit ≈ ₹7,083', approx(s.realizedProfit, 7083.33, 1));
  check('trade receivable ₹1,73,650 / payable ₹79,400',
    approx(s.totalReceivable, 173650, 1) && approx(s.totalPayable, 79400, 1));
  check('cash loan outstanding ≈ principal + ~3 days interest',
    approx(s.loanCashPrincipal, 100000) && between(s.loanCashInterestAccrued, 200, 400) &&
    approx(s.loanCashOutstanding, s.loanCashPrincipal + s.loanCashInterestAccrued, 0.5));
  check('gold loan outstanding ≈ 50 g + ~0.5 g interest',
    approx(s.loanGoldPrincipalGrams, 50) &&
    between(s.loanGoldInterestAccruedGrams, 0.4, 0.6) &&
    approx(s.loanGoldOutstandingGrams, 50.5, 0.1));
  check('interest earned (cash) from the repaid loan = ₹2,000',
    approx(s.interestEarnedCash, 2000));

  // --- loans list + filters ---
  r = await GET('/api/loans', H);
  check('3 loans', r.body.length === 3);
  check('filter status=open -> 2', (await GET('/api/loans?status=open', H)).body.length === 2);
  check('filter status=repaid -> 1', (await GET('/api/loans?status=repaid', H)).body.length === 1);
  check('filter kind=gold -> 1', (await GET('/api/loans?kind=gold', H)).body.length === 1);
  check('search q=anbu -> 1', (await GET('/api/loans?q=anbu', H)).body.length === 1);

  const anbu = r.body.find((l) => l.party === 'Anbu');
  check('Anbu: 3 days elapsed, ~₹300 accrued, outstanding ~₹1,00,300',
    anbu.daysElapsed === 3 && between(anbu.accruedInterest, 200, 400) &&
    approx(anbu.outstanding, 100000 + anbu.accruedInterest, 0.5));
  const vijay = r.body.find((l) => l.party === 'Vijay');
  check('Vijay: countStartDay adds a day -> 20 days elapsed',
    vijay.daysElapsed === 20 && between(vijay.accruedInterest, 0.4, 0.6));

  // --- lending guards ---
  check('lend more gold than in stock -> 422',
    (await POST('/api/loans', H, {
      kind: 'gold', party: 'X', principal: 500, interestRate: 1.5,
      interestRefAmount: 100, interestUnit: 'month',
    })).status === 422);
  check('lend more cash than in hand -> 422',
    (await POST('/api/loans', H, {
      kind: 'cash', party: 'X', principal: 99999999, interestRate: 100,
      interestRefAmount: 100000, interestUnit: 'day',
    })).status === 422);

  // --- give a cash loan, then repay it same day (no interest) ---
  r = await POST('/api/loans', H, {
    kind: 'cash', party: 'Test Borrower', principal: 50000,
    interestRate: 100, interestRefAmount: 100000, interestUnit: 'day', countStartDay: false,
  });
  check('give ₹50,000 cash loan -> 201, open', r.status === 201 && r.body.status === 'open');
  const loanId = r.body.id;
  check('cash in hand drops by 50,000',
    approx((await GET('/api/stock', H)).body.cashInHand, 1076000 - 50000, 1));

  r = await POST(`/api/loans/${loanId}/repay`, H, {});
  check('repay same day -> repaid, ₹0 interest',
    r.status === 200 && r.body.status === 'repaid' && approx(r.body.repayment.interestPaid, 0));
  check('cash in hand back to ₹10,76,000',
    approx((await GET('/api/stock', H)).body.cashInHand, 1076000, 1));
  check('repay again -> 409',
    (await POST(`/api/loans/${loanId}/repay`, H, {})).status === 409);
  await DEL(`/api/loans/${loanId}`, H);

  // --- selling is limited by physical stock (90 g), not just trades ---
  check('sell 200 g -> 422 (only ~90 g in stock)',
    (await POST('/api/transactions', H, {
      type: 'sale', weightGrams: 200, ratePerGram: 6000,
    })).status === 422);

  // --- trade dues still work: settle a bill, search, date filter ---
  r = await GET('/api/transactions?q=kumar', H);
  check('search q=kumar -> 2 sales', r.body.length === 2 && r.body.every((t) => t.type === 'sale'));
  const s118 = r.body.find((t) => t.note === 'bill S-118');
  r = await POST(`/api/transactions/${s118.id}/payments`, H, { amount: 51250, note: 'upi' });
  check('pay off bill S-118 -> paid', r.status === 201 && r.body.paymentStatus === 'paid');
  check('cash in hand rose by 51,250',
    approx((await GET('/api/stock', H)).body.cashInHand, 1076000 + 51250, 1));

  r = await GET('/api/transactions?from=2026-09-01&to=2026-09-30', H);
  check('date filter Sept -> all rows in range',
    r.body.length >= 2 && r.body.every((t) => new Date(t.date) >= new Date('2026-09-01')));

  // --- outstanding grouped by party (Kumar had 2 bills; S-118 now cleared) ---
  r = await GET('/api/outstanding', H);
  const kumar = r.body.receivables.find((x) => x.party === 'Kumar Jewellery');
  check('Kumar now owes only bill S-121 (₹1,22,400)',
    kumar && kumar.count === 1 && approx(kumar.totalDue, 122400, 1));

  server.close();
  await mongoose.disconnect();
  await mem.stop();
  console.log(`\n${pass} checks passed`);
}

main().catch((err) => {
  console.error('\nsmoke test errored:', err.message);
  process.exit(1);
});
