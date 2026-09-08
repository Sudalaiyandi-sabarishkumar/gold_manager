// Run the real API against a throwaway in-memory MongoDB, seeded with the
// sample ledger. For local development / trying the app without installing
// MongoDB. Data is NOT persisted between runs.
//
//   npm run dev:mem
require('dotenv').config();
process.env.JWT_SECRET = process.env.JWT_SECRET || 'dev-mem-secret';

const { MongoMemoryServer } = require('mongodb-memory-server');
const bcrypt = require('bcryptjs');

const { createApp } = require('./app');
const { connectDb } = require('./config/db');
const User = require('./models/User');
const Transaction = require('./models/Transaction');
const { SAMPLE } = require('./seed');

const PORT = process.env.PORT || 3000;

(async () => {
  const mem = await MongoMemoryServer.create();
  await connectDb(mem.getUri('gold_manager'));

  const username = (process.env.SEED_USERNAME || 'mani').toLowerCase();
  const password = process.env.SEED_PASSWORD || '1977';

  await User.findOneAndUpdate(
    { username },
    { username, passwordHash: await bcrypt.hash(password, 10) },
    { upsert: true }
  );
  await Transaction.insertMany(
    SAMPLE.map((t) => ({
      ...t,
      date: new Date(t.date),
      totalAmount: Math.round(t.weightGrams * t.ratePerGram * 100) / 100,
    }))
  );
  console.log(`[dev-mem] seeded ${username}/${password} + ${SAMPLE.length} transactions`);

  const server = createApp().listen(PORT, () => {
    console.log(`[dev-mem] API on http://localhost:${PORT}  (in-memory Mongo — not persisted)`);
  });

  const shutdown = async () => {
    server.close();
    await mem.stop();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
})().catch((err) => {
  console.error('[dev-mem] failed:', err);
  process.exit(1);
});
