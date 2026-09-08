const express = require('express');
const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const Loan = require('../models/Loan');
const Settings = require('../models/Settings');
const { replayStock } = require('../services/stock');
const { summarizePayments, round2 } = require('../services/payments');
const { computeBalances } = require('../services/balances');
const ah = require('../lib/asyncHandler');

const router = express.Router();

function serialize(t, perTxn) {
  const extra = perTxn && perTxn.get(String(t._id));
  const pay = summarizePayments(t);
  return {
    id: String(t._id),
    type: t.type,
    date: t.date,
    party: t.party || '',
    weightGrams: t.weightGrams,
    ratePerGram: t.ratePerGram,
    totalAmount: t.totalAmount,
    note: t.note || '',
    createdAt: t.createdAt,
    balanceAfter: extra ? extra.balanceAfter : null,
    avgCostAfter: extra ? extra.avgCostAfter : null,
    profit: extra ? extra.profit : null,
    amountPaid: pay.amountPaid,
    amountDue: pay.amountDue,
    paymentStatus: pay.paymentStatus,
    payments: (t.payments || [])
      .slice()
      .sort((a, b) => new Date(a.date) - new Date(b.date))
      .map((p) => ({
        id: String(p._id),
        amount: p.amount,
        date: p.date,
        note: p.note || '',
      })),
  };
}

function byDateDesc(a, b) {
  return (
    new Date(b.date) - new Date(a.date) ||
    new Date(b.createdAt || 0) - new Date(a.createdAt || 0)
  );
}

const startOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 0, 0, 0, 0);
const endOfDay = (d) => new Date(d.getFullYear(), d.getMonth(), d.getDate(), 23, 59, 59, 999);

// Reuse the existing spelling of a party name if one already exists
// (case-insensitive), so the same person is not split by casing/whitespace.
async function canonicalParty(name) {
  const raw = (name || '').toString().trim();
  if (!raw) return '';
  const escaped = raw.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const existing = await Transaction.findOne({ party: new RegExp(`^${escaped}$`, 'i') })
    .select('party')
    .lean();
  return existing && existing.party ? existing.party : raw;
}

// GET /api/transactions?type=purchase|sale&q=<name/note>&from=<date>&to=<date>
router.get(
  '/',
  ah(async (req, res) => {
    const all = await Transaction.find().lean();
    const { perTxn } = replayStock(all);

    let list = all.slice().sort(byDateDesc);

    const { type, q, from, to } = req.query;
    if (type === 'purchase' || type === 'sale') {
      list = list.filter((t) => t.type === type);
    }
    if (from) {
      const f = new Date(from);
      if (!Number.isNaN(f.getTime())) {
        list = list.filter((t) => new Date(t.date) >= startOfDay(f));
      }
    }
    if (to) {
      const tt = new Date(to);
      if (!Number.isNaN(tt.getTime())) {
        list = list.filter((t) => new Date(t.date) <= endOfDay(tt));
      }
    }
    if (q && q.trim()) {
      const needle = q.trim().toLowerCase();
      list = list.filter(
        (t) =>
          (t.party || '').toLowerCase().includes(needle) ||
          (t.note || '').toLowerCase().includes(needle)
      );
    }

    res.json(list.map((t) => serialize(t, perTxn)));
  })
);

// GET /api/transactions/:id
router.get(
  '/:id',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const all = await Transaction.find().lean();
    const { perTxn } = replayStock(all);
    const t = all.find((x) => String(x._id) === req.params.id);
    if (!t) return res.status(404).json({ error: 'Not found' });
    res.json(serialize(t, perTxn));
  })
);

// POST /api/transactions
// { type, date?, party?, weightGrams, ratePerGram, note?, amountPaid? }
// amountPaid defaults to the full total; clamp to [0, total].
router.post(
  '/',
  ah(async (req, res) => {
    const { type, date, weightGrams, ratePerGram, note, party, amountPaid } = req.body || {};

    if (type !== 'purchase' && type !== 'sale') {
      return res.status(400).json({ error: "type must be 'purchase' or 'sale'" });
    }
    const w = Number(weightGrams);
    const r = Number(ratePerGram);
    if (!(w > 0)) return res.status(400).json({ error: 'weightGrams must be greater than 0' });
    if (!(r >= 0)) return res.status(400).json({ error: 'ratePerGram must be 0 or more' });

    const when = date ? new Date(date) : new Date();
    if (Number.isNaN(when.getTime())) return res.status(400).json({ error: 'date is invalid' });

    if (type === 'sale') {
      const [settings, all, loans] = await Promise.all([
        Settings.current(),
        Transaction.find().lean(),
        Loan.find().lean(),
      ]);
      const available = computeBalances({
        openingCash: settings.openingCash,
        openingGoldGrams: settings.openingGoldGrams,
        transactions: all,
        loans,
      }).goldInStockGrams;
      if (w > available + 1e-9) {
        return res.status(422).json({
          error: `Only ${available.toFixed(2)} g in stock`,
          availableGrams: available,
        });
      }
    }

    const total = round2(w * r);
    let paidNow = amountPaid === undefined || amountPaid === null ? total : Number(amountPaid);
    if (Number.isNaN(paidNow) || paidNow < 0) paidNow = 0;
    if (paidNow > total) paidNow = total;

    const payments =
      paidNow > 0.005 ? [{ amount: round2(paidNow), date: when, note: 'Initial payment' }] : [];

    const doc = await Transaction.create({
      type,
      date: when,
      party: await canonicalParty(party),
      weightGrams: w,
      ratePerGram: r,
      totalAmount: total,
      note: (note || '').toString().trim(),
      payments,
    });

    const all = await Transaction.find().lean();
    const { perTxn } = replayStock(all);
    res.status(201).json(serialize(doc.toObject(), perTxn));
  })
);

// POST /api/transactions/:id/payments  { amount, date?, note? }
router.post(
  '/:id/payments',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const doc = await Transaction.findById(req.params.id);
    if (!doc) return res.status(404).json({ error: 'Not found' });

    const amt = Number(req.body && req.body.amount);
    if (!(amt > 0)) return res.status(400).json({ error: 'amount must be greater than 0' });

    const { amountDue } = summarizePayments(doc.toObject());
    if (amt > amountDue + 0.005) {
      return res.status(422).json({
        error: `Only ${amountDue.toFixed(2)} outstanding`,
        amountDue,
      });
    }

    const when = req.body && req.body.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(when.getTime())) return res.status(400).json({ error: 'date is invalid' });

    doc.payments.push({
      amount: round2(amt),
      date: when,
      note: ((req.body && req.body.note) || '').toString().trim(),
    });
    await doc.save();

    const all = await Transaction.find().lean();
    const { perTxn } = replayStock(all);
    res.status(201).json(serialize(doc.toObject(), perTxn));
  })
);

// DELETE /api/transactions/:id/payments/:paymentId
router.delete(
  '/:id/payments/:paymentId',
  ah(async (req, res) => {
    if (
      !mongoose.isValidObjectId(req.params.id) ||
      !mongoose.isValidObjectId(req.params.paymentId)
    ) {
      return res.status(404).json({ error: 'Not found' });
    }
    const doc = await Transaction.findById(req.params.id);
    if (!doc || !doc.payments.id(req.params.paymentId)) {
      return res.status(404).json({ error: 'Not found' });
    }
    doc.payments.pull(req.params.paymentId);
    await doc.save();

    const all = await Transaction.find().lean();
    const { perTxn } = replayStock(all);
    res.json(serialize(doc.toObject(), perTxn));
  })
);

// DELETE /api/transactions/:id
router.delete(
  '/:id',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const deleted = await Transaction.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Not found' });
    res.json({ ok: true });
  })
);

module.exports = router;
