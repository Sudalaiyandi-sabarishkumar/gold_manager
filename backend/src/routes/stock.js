const express = require('express');
const Transaction = require('../models/Transaction');
const { replayStock } = require('../services/stock');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// GET /api/stock -> current pool summary
router.get(
  '/',
  ah(async (req, res) => {
    const txns = await Transaction.find().lean();
    const s = replayStock(txns);
    res.json({
      weightGrams: s.weightGrams,
      avgCostPerGram: s.avgCostPerGram,
      stockValue: s.stockValue,
      realizedProfit: s.realizedProfit,
      lastRatePerGram: s.lastRatePerGram,
      transactionCount: txns.length,
    });
  })
);

module.exports = router;
