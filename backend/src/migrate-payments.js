// One-off migration for the payments/party feature.
// Existing transactions predate settlement tracking: mark each as paid in full
// (a single payment for the whole total) and ensure a `party` field exists.
// Safe to re-run — it only touches transactions with no payments recorded.
//
//   node src/migrate-payments.js
require('dotenv').config();
const mongoose = require('mongoose');
const { connectDb } = require('./config/db');
const Transaction = require('./models/Transaction');

async function main() {
  await connectDb(process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager');

  const legacy = await Transaction.find({
    $or: [{ payments: { $exists: false } }, { payments: { $size: 0 } }],
  });

  let migrated = 0;
  for (const t of legacy) {
    t.payments = [
      { amount: t.totalAmount, date: t.date, note: 'Migrated: assumed paid in full' },
    ];
    if (t.party === undefined || t.party === null) t.party = '';
    await t.save();
    migrated += 1;
  }

  console.log(`[migrate] marked ${migrated} legacy transaction(s) as paid in full`);
  await mongoose.disconnect();
}

main().catch((err) => {
  console.error('[migrate] failed:', err.message);
  process.exit(1);
});
