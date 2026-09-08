const express = require('express');
const Transaction = require('../models/Transaction');
const Loan = require('../models/Loan');
const Settings = require('../models/Settings');
const { replayStock } = require('../services/stock');
const { outstanding } = require('../services/payments');
const { computeBalances } = require('../services/balances');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// GET /api/stock -> unified position: cash, gold, trade P&L, trade dues, loans out
router.get(
  '/',
  ah(async (req, res) => {
    const [settings, txns, loans] = await Promise.all([
      Settings.current(),
      Transaction.find().lean(),
      Loan.find().lean(),
    ]);

    const trade = replayStock(txns);
    const o = outstanding(txns);
    const b = computeBalances({
      openingCash: settings.openingCash,
      openingGoldGrams: settings.openingGoldGrams,
      transactions: txns,
      loans,
    });

    res.json({
      // physical position
      cashInHand: b.cashInHand,
      weightGrams: b.goldInStockGrams, // gold physically in stock
      openingCash: b.openingCash,
      openingGoldGrams: b.openingGoldGrams,

      // trade valuation / P&L
      avgCostPerGram: trade.avgCostPerGram,
      stockValue: b.goldStockValue,
      realizedProfit: trade.realizedProfit,
      lastRatePerGram: trade.lastRatePerGram,
      transactionCount: txns.length,

      // trade dues (bills)
      totalReceivable: o.totalReceivable,
      totalPayable: o.totalPayable,

      // loans given out
      loanCashPrincipal: b.loanCashPrincipal,
      loanCashInterestAccrued: b.loanCashInterestAccrued,
      loanCashOutstanding: b.loanCashOutstanding,
      loanGoldPrincipalGrams: b.loanGoldPrincipalGrams,
      loanGoldInterestAccruedGrams: b.loanGoldInterestAccruedGrams,
      loanGoldOutstandingGrams: b.loanGoldOutstandingGrams,
      interestEarnedCash: b.interestEarnedCash,
      interestEarnedGoldGrams: b.interestEarnedGoldGrams,
    });
  })
);

module.exports = router;
