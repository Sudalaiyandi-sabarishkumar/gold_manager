require('dotenv').config();
const { createApp } = require('./app');
const { connectDb } = require('./config/db');

const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || 'mongodb://127.0.0.1:27017/gold_manager';

// Fail closed: never fall back to a default secret, or anyone who reads the
// source could forge login tokens.
const secret = process.env.JWT_SECRET || '';
if (secret.length < 32 || /^(replace-with|dev-insecure|changeme)/i.test(secret)) {
  console.error(
    '[fatal] JWT_SECRET is missing, too short (<32 chars) or a placeholder.\n' +
      '        Generate one with: openssl rand -hex 32'
  );
  process.exit(1);
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
