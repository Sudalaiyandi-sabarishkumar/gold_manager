require('dotenv').config();
const mongoose = require('mongoose');
const bcrypt = require('bcryptjs');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');

const USERNAME = (process.env.SEED_USERNAME || 'mani').toLowerCase();
const PASSWORD = process.env.SEED_PASSWORD || '1977';
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager';

// Same six entries as the visual prototype.
const SAMPLE = [
  { type: 'purchase', date: '2026-08-12', weightGrams: 500, ratePerGram: 5880, note: 'Opening stock' },
  { type: 'purchase', date: '2026-08-19', weightGrams: 300, ratePerGram: 5910, note: 'Ravi Jewellers · bill 4471' },
  { type: 'sale', date: '2026-08-27', weightGrams: 150, ratePerGram: 6040, note: 'Retail counter' },
  { type: 'purchase', date: '2026-09-01', weightGrams: 200, ratePerGram: 5950, note: 'MMTC lot' },
  { type: 'sale', date: '2026-09-04', weightGrams: 90, ratePerGram: 6110, note: 'Retail counter' },
  { type: 'purchase', date: '2026-09-06', weightGrams: 100, ratePerGram: 5990, note: 'Ravi Jewellers · bill 4502' },
];

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
  const docs = SAMPLE.map((t) => ({
    ...t,
    date: new Date(t.date),
    totalAmount: Math.round(t.weightGrams * t.ratePerGram * 100) / 100,
  }));
  await Transaction.insertMany(docs);
  console.log(`[seed] inserted ${docs.length} transactions`);

  await mongoose.disconnect();
  console.log('[seed] done');
}

if (require.main === module) {
  seed().catch((err) => {
    console.error('[seed] failed:', err.message);
    process.exit(1);
  });
}

module.exports = { SAMPLE, seed };
