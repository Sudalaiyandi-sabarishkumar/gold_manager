require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const Loan = require('./models/Loan');
const Settings = require('./models/Settings');
const { round2 } = require('./services/payments');

const USERNAME = (process.env.SEED_USERNAME || 'mani').toLowerCase();
const PASSWORD = process.env.SEED_PASSWORD || '1977';
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager';

const OPENING_CASH = 1500000;
const OPENING_GOLD_GRAMS = 100;

const DAY = 86400000;
const daysAgo = (n) => new Date(Date.now() - n * DAY);

// Modest trades on top of the opening position.
//   paidFull: true  -> settled in full   |   paid: <n> -> that much settled
const SAMPLE = [
  { type: 'purchase', date: '2026-08-15', weightGrams: 40, ratePerGram: 5900, party: 'Ravi Jewellers', note: 'bill 4471', paidFull: true },
  { type: 'sale', date: '2026-08-22', weightGrams: 25, ratePerGram: 6050, party: 'Kumar Jewellery', note: 'bill S-118', paid: 100000 },
  { type: 'purchase', date: '2026-09-02', weightGrams: 30, ratePerGram: 5980, party: 'MMTC', note: 'lot 92', paid: 100000 },
  { type: 'sale', date: '2026-09-05', weightGrams: 20, ratePerGram: 6120, party: 'Kumar Jewellery', note: 'bill S-121', paid: 0 },
  { type: 'purchase', date: '2026-09-07', weightGrams: 15, ratePerGram: 6000, party: 'Ravi Jewellers', note: 'bill 4502', paidFull: true },
];

// Loan dates are relative to "now" so accrued interest is stable whenever this runs.
const SAMPLE_LOANS = [
  {
    kind: 'cash',
    party: 'Anbu',
    date: daysAgo(3),
    principal: 100000,
    interestRate: 100,
    interestRefAmount: 100000,
    interestUnit: 'day',
    countStartDay: false,
    note: 'short term',
  },
  {
    kind: 'gold',
    party: 'Vijay',
    date: daysAgo(19),
    principal: 50,
    interestRate: 1.5,
    interestRefAmount: 100,
    interestUnit: 'month',
    countStartDay: true,
    note: 'ornament loan',
  },
  {
    kind: 'cash',
    party: 'Selvam',
    date: daysAgo(40),
    principal: 200000,
    interestRate: 100,
    interestRefAmount: 100000,
    interestUnit: 'day',
    countStartDay: false,
    note: 'cleared',
    repayment: { date: daysAgo(30), principalReturned: 200000, interestPaid: 2000, note: 'neft' },
  },
];

function buildTxn(t) {
  const total = round2(t.weightGrams * t.ratePerGram);
  const paid = t.paidFull ? total : Math.min(t.paid || 0, total);
  const payments =
    paid > 0 ? [{ amount: round2(paid), date: new Date(t.date), note: 'Initial payment' }] : [];
  return {
    type: t.type,
    date: new Date(t.date),
    party: t.party,
    weightGrams: t.weightGrams,
    ratePerGram: t.ratePerGram,
    totalAmount: total,
    note: t.note,
    payments,
  };
}

async function seed() {
  await connectDb(MONGO_URI);

  const passwordHash = await bcrypt.hash(PASSWORD, 10);
  await User.findOneAndUpdate(
    { username: USERNAME },
    { username: USERNAME, passwordHash },
    { upsert: true, new: true }
  );
  console.log(`[seed] user "${USERNAME}" ready`);

  await Settings.findByIdAndUpdate(
    'app',
    { _id: 'app', openingCash: OPENING_CASH, openingGoldGrams: OPENING_GOLD_GRAMS },
    { upsert: true }
  );
  console.log(`[seed] opening: ₹${OPENING_CASH} + ${OPENING_GOLD_GRAMS} g`);

  await Transaction.deleteMany({});
  await Transaction.insertMany(SAMPLE.map(buildTxn));
  console.log(`[seed] inserted ${SAMPLE.length} transactions`);

  await Loan.deleteMany({});
  await Loan.insertMany(SAMPLE_LOANS);
  console.log(`[seed] inserted ${SAMPLE_LOANS.length} loans`);

  await mongoose.disconnect();
  console.log('[seed] done');
}

if (require.main === module) {
  seed().catch((err) => {
    console.error('[seed] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { SAMPLE, SAMPLE_LOANS, buildTxn, seed, OPENING_CASH, OPENING_GOLD_GRAMS };
