const express = require('express');
const Transaction = require('../models/Transaction');
const { outstanding } = require('../services/payments');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// GET /api/outstanding -> receivables / payables grouped by party (current user only)
router.get(
  '/',
  ah(async (req, res) => {
    const txns = await Transaction.find({ userId: req.user.sub }).lean();
    res.json(outstanding(txns));
  })
);

module.exports = router;
