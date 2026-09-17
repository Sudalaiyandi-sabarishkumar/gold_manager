const express = require('express');
const mongoose = require('mongoose');
const Expense = require('../models/Expense');
const Transaction = require('../models/Transaction');
const Loan = require('../models/Loan');
const Settings = require('../models/Settings');
const { computeBalances, balanceSeedFromSettings } = require('../services/balances');
const { round2 } = require('../services/payments');
const ah = require('../lib/asyncHandler');

const router = express.Router();

const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
const endOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);

async function cashInHand() {
  const [settings, transactions, loans, expenses] = await Promise.all([
    Settings.current(),
    Transaction.find().lean(),
    Loan.find().lean(),
    Expense.find().lean(),
  ]);
  return computeBalances({
    openingCash: settings.openingCash,
    openingGoldGrams: settings.openingGoldGrams,
    ...balanceSeedFromSettings(settings),
    transactions,
    loans,
    expenses,
  }).cashInHand;
}

function serialize(e) {
  return {
    id: String(e._id),
    date: e.date,
    amount: e.amount,
    note: e.note || '',
    createdAt: e.createdAt,
  };
}

// GET /api/expenses?q=<note>&from=<date>&to=<date>
router.get(
  '/',
  ah(async (req, res) => {
    let list = await Expense.find().sort({ date: -1, createdAt: -1 }).lean();

    const { q, from, to } = req.query;
    if (from) {
      const f = new Date(from);
      if (!Number.isNaN(f.getTime())) list = list.filter((e) => new Date(e.date) >= startOfDay(f));
    }
    if (to) {
      const t = new Date(to);
      if (!Number.isNaN(t.getTime())) list = list.filter((e) => new Date(e.date) <= endOfDay(t));
    }
    if (q && q.trim()) {
      const needle = q.trim().toLowerCase();
      list = list.filter((e) => (e.note || '').toLowerCase().includes(needle));
    }

    res.json(list.map(serialize));
  })
);

// POST /api/expenses  { date?, amount, note? }
router.post(
  '/',
  ah(async (req, res) => {
    const { date, amount, note } = req.body || {};
    const amt = Number(amount);
    if (!(amt > 0)) return res.status(400).json({ error: 'amount must be greater than 0' });

    const when = date ? new Date(date) : new Date();
    if (Number.isNaN(when.getTime())) return res.status(400).json({ error: 'date is invalid' });

    const available = await cashInHand();
    if (amt > available + 1e-6) {
      return res.status(422).json({
        error: `Only ₹${available.toFixed(2)} cash in hand`,
        available,
      });
    }

    const doc = await Expense.create({
      date: when,
      amount: round2(amt),
      note: (note || '').toString().trim(),
    });
    res.status(201).json(serialize(doc.toObject()));
  })
);

// DELETE /api/expenses/:id
router.delete(
  '/:id',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const deleted = await Expense.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Not found' });
    res.json({ ok: true });
  })
);

module.exports = router;
