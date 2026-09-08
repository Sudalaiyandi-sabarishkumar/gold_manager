require('dotenv').config();
const { createApp } = require('./app');
const { connectDb } = require('./config/db');

const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager';

if (!process.env.JWT_SECRET) {
  console.warn('[warn] JWT_SECRET is not set — using an insecure development default');
  process.env.JWT_SECRET = 'dev-insecure-secret';
}

connectDb(MONGO_URI)
  .then(() => {
    createApp().listen(PORT, () => {
      console.log(`[api] listening on http://localhost:${PORT}`);
    });
  })
  .catch((err) => {
    console.error('[db] connection failed:', err.message);
    console.error('     Is MongoDB running? See backend/README or use `npm run smoke`.');
    process.exit(1);
  });
