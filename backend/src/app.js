const express = require('express');
const cors = require('cors');

const auth = require('./middleware/auth');
const authRoutes = require('./routes/auth');
const stockRoutes = require('./routes/stock');
const transactionRoutes = require('./routes/transactions');

function createApp() {
  const app = express();
  app.use(cors());
  app.use(express.json());

  app.get('/health', (req, res) => res.json({ ok: true }));

  app.use('/api/auth', authRoutes);
  app.use('/api/stock', auth, stockRoutes);
  app.use('/api/transactions', auth, transactionRoutes);

  app.use((req, res) => res.status(404).json({ error: 'Not found' }));

  // eslint-disable-next-line no-unused-vars
  app.use((err, req, res, next) => {
    console.error('[error]', err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}

module.exports = { createApp };
