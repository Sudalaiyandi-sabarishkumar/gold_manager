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
const { SAMPLE, buildDoc } = require('./seed');

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

async function main() {
  const mem = await MongoMemoryServer.create();
  await connectDb(mem.getUri('gold_manager'));

  await User.findOneAndUpdate(
    { username: 'mani' },
    { username: 'mani', passwordHash: await bcrypt.hash('1977', 10) },
    { upsert: true }
  );
  await Transaction.insertMany(SAMPLE.map(buildDoc));

  const app = createApp();
  const server = app.listen(0);
  const base = `http://127.0.0.1:${server.address().port}`;
  const json = async (res) => ({ status: res.status, body: await res.json().catch(() => null) });

  // --- auth ---
  let r = await json(
    await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'mani', password: '1977' }),
    })
  );
  check('login with mani/1977 -> 200 + token', r.status === 200 && typeof r.body.token === 'string');
  const token = r.body.token;
  const authH = { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' };

  r = await json(
    await fetch(`${base}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username: 'mani', password: 'wrong' }),
    })
  );
  check('login with wrong password -> 401', r.status === 401);

  r = await json(await fetch(`${base}/api/stock`));
  check('GET /api/stock without token -> 401', r.status === 401);

  // --- stock + outstanding from seed ---
  r = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('seeded stock weight = 860 g', approx(r.body.weightGrams, 860));
  check('seeded avg cost ~ 5914.95 /g', approx(r.body.avgCostPerGram, 5914.95, 0.05));
  check('seeded realized profit ~ 40756', approx(r.body.realizedProfit, 40755.88, 1));
  check('seeded receivable = 9,55,900', approx(r.body.totalReceivable, 955900, 1));
  check('seeded payable = 3,90,000', approx(r.body.totalPayable, 390000, 1));

  // --- payment state on a seeded partial sale ---
  r = await json(await fetch(`${base}/api/transactions?type=sale`, { headers: authH }));
  const partialSale = r.body.find((t) => t.weightGrams === 150 && t.party === 'Kumar Jewellery');
  check(
    'seeded sale is partial: paid 5,00,000 / due 4,06,000',
    Boolean(partialSale) &&
      approx(partialSale.amountPaid, 500000) &&
      approx(partialSale.amountDue, 406000) &&
      partialSale.paymentStatus === 'partial' &&
      partialSale.payments.length === 1
  );
  const unpaidSale = r.body.find((t) => t.weightGrams === 90 && t.party === 'Kumar Jewellery');
  check('seeded sale is unpaid: due 5,49,900', unpaidSale && unpaidSale.paymentStatus === 'unpaid');

  // --- add a payment -> paid in full ---
  r = await json(
    await fetch(`${base}/api/transactions/${partialSale.id}/payments`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({ amount: 406000, note: 'balance cleared' }),
    })
  );
  check('add payment -> 201, status paid, due 0, 2 payments',
    r.status === 201 && r.body.paymentStatus === 'paid' && approx(r.body.amountDue, 0) &&
    r.body.payments.length === 2);

  const afterPay = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('receivable drops to 5,49,900 after payment', approx(afterPay.body.totalReceivable, 549900, 1));

  // --- overpay rejected ---
  r = await json(
    await fetch(`${base}/api/transactions/${unpaidSale.id}/payments`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({ amount: 999999999 }),
    })
  );
  check('overpay -> 422 with outstanding message', r.status === 422 && /outstanding/.test(r.body.error));

  // --- delete a payment -> back to partial ---
  r = await json(await fetch(`${base}/api/transactions/${partialSale.id}`, { headers: authH }));
  const payToDelete = r.body.payments.find((p) => p.note === 'balance cleared');
  r = await json(
    await fetch(`${base}/api/transactions/${partialSale.id}/payments/${payToDelete.id}`, {
      method: 'DELETE',
      headers: authH,
    })
  );
  check('delete payment -> back to partial, due 4,06,000',
    r.status === 200 && r.body.paymentStatus === 'partial' && approx(r.body.amountDue, 406000));

  // --- create with partial payment ---
  r = await json(
    await fetch(`${base}/api/transactions`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({
        type: 'purchase', date: '2026-09-08', party: 'Test Seller',
        weightGrams: 10, ratePerGram: 6000, amountPaid: 20000,
      }),
    })
  );
  check('create purchase with amountPaid 20000 -> partial, due 40000',
    r.status === 201 && r.body.paymentStatus === 'partial' && approx(r.body.amountDue, 40000));

  // --- create defaulting to paid in full ---
  r = await json(
    await fetch(`${base}/api/transactions`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({ type: 'purchase', date: '2026-09-08', weightGrams: 100, ratePerGram: 7000 }),
    })
  );
  check('create without amountPaid -> paid in full', r.status === 201 && r.body.paymentStatus === 'paid');
  check('purchase total computed server-side (700000)', r.body.totalAmount === 700000);

  const afterBuy = await json(await fetch(`${base}/api/stock`, { headers: authH }));
  check('weight rises by 110 -> 970 g', approx(afterBuy.body.weightGrams, 970));
  check('payable rose by 40000 (Test Seller balance)', approx(afterBuy.body.totalPayable, 430000, 1));

  // --- over-sell rejected ---
  r = await json(
    await fetch(`${base}/api/transactions`, {
      method: 'POST',
      headers: authH,
      body: JSON.stringify({ type: 'sale', weightGrams: 5000, ratePerGram: 6200 }),
    })
  );
  check('over-sell -> 422', r.status === 422 && /available/.test(r.body.error));

  // --- search by name ---
  r = await json(await fetch(`${base}/api/transactions?q=kumar`, { headers: authH }));
  check('search q=kumar -> only Kumar Jewellery rows',
    r.body.length === 2 && r.body.every((t) => t.party.toLowerCase().includes('kumar')));

  // --- filter by date range ---
  r = await json(
    await fetch(`${base}/api/transactions?from=2026-09-01&to=2026-09-30`, { headers: authH })
  );
  check('date filter -> every row on/after 2026-09-01',
    r.body.length >= 3 && r.body.every((t) => new Date(t.date) >= new Date('2026-09-01')));
  r = await json(
    await fetch(`${base}/api/transactions?from=2026-08-01&to=2026-08-31`, { headers: authH })
  );
  check('date filter Aug -> every row in August',
    r.body.every((t) => new Date(t.date) < new Date('2026-09-01')));

  // --- outstanding grouped by party ---
  r = await json(await fetch(`${base}/api/outstanding`, { headers: authH }));
  const kumar = r.body.receivables.find((x) => x.party === 'Kumar Jewellery');
  check('outstanding: Kumar owes 9,55,900 across 2 bills',
    kumar && approx(kumar.totalDue, 955900, 1) && kumar.count === 2);
  const mmtc = r.body.payables.find((x) => x.party === 'MMTC');
  check('outstanding: we owe MMTC 3,90,000', mmtc && approx(mmtc.totalDue, 390000, 1));

  server.close();
  await mongoose.disconnect();
  await mem.stop();
  console.log(`\n${pass} checks passed`);
}

main().catch((err) => {
  console.error('\nsmoke test errored:', err.message);
  process.exit(1);
});
