require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const { round2 } = require('./services/payments');

const USERNAME = (process.env.SEED_USERNAME || 'mani').toLowerCase();
const PASSWORD = process.env.SEED_PASSWORD || '1977';
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager';

// Same gold movements as before; now with party names and mixed payment states.
//   paidFull: true  -> settled in full
//   paid: <number>   -> that much settled, rest outstanding (0 = fully unpaid)
const SAMPLE = [
  { type: 'purchase', date: '2026-08-12', weightGrams: 500, ratePerGram: 5880, party: '', note: 'Opening stock', paidFull: true },
  { type: 'purchase', date: '2026-08-19', weightGrams: 300, ratePerGram: 5910, party: 'Ravi Jewellers', note: 'bill 4471', paidFull: true },
  { type: 'sale', date: '2026-08-27', weightGrams: 150, ratePerGram: 6040, party: 'Kumar Jewellery', note: 'bill S-118', paid: 500000 },
  { type: 'purchase', date: '2026-09-01', weightGrams: 200, ratePerGram: 5950, party: 'MMTC', note: 'lot 92', paid: 800000 },
  { type: 'sale', date: '2026-09-04', weightGrams: 90, ratePerGram: 6110, party: 'Kumar Jewellery', note: 'bill S-121', paid: 0 },
  { type: 'purchase', date: '2026-09-06', weightGrams: 100, ratePerGram: 5990, party: 'Ravi Jewellers', note: 'bill 4502', paidFull: true },
];

function buildDoc(t) {
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

  await Transaction.deleteMany({});
  await Transaction.insertMany(SAMPLE.map(buildDoc));
  console.log(`[seed] inserted ${SAMPLE.length} transactions`);

  await mongoose.disconnect();
  console.log('[seed] done');
}

if (require.main === module) {
  seed().catch((err) => {
    console.error('[seed] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { SAMPLE, buildDoc, seed };
