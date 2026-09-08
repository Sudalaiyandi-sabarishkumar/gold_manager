const express = require('express');
const Transaction = require('../models/Transaction');
const { outstanding } = require('../services/payments');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// GET /api/outstanding -> receivables / payables grouped by party
router.get(
  '/',
  ah(async (req, res) => {
    const txns = await Transaction.find().lean();
    res.json(outstanding(txns));
  })
);

module.exports = router;
