const express = require('express');
const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const { summarizePayments, round2 } = require('../services/payments');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// POST /api/parties/settle
// { allocations: [{ transactionId, amount, date?, note? }] }
//
// Records one payment per listed bill in a single call. Every allocation is
// validated first; nothing is written unless all pass.
router.post(
  '/settle',
  ah(async (req, res) => {
    const allocations = Array.isArray(req.body && req.body.allocations)
      ? req.body.allocations
      : [];
    if (allocations.length === 0) {
      return res.status(400).json({ error: 'allocations is required' });
    }

    const prepared = [];
    const seen = new Set();
    for (const a of allocations) {
      if (!mongoose.isValidObjectId(a.transactionId)) {
        return res.status(400).json({ error: `bad transactionId: ${a.transactionId}` });
      }
      if (seen.has(a.transactionId)) {
        return res.status(400).json({ error: 'a bill is listed twice' });
      }
      seen.add(a.transactionId);

      const amt = Number(a.amount);
      if (!(amt > 0)) {
        return res.status(400).json({ error: 'each amount must be greater than 0' });
      }
      const doc = await Transaction.findById(a.transactionId);
      if (!doc) {
        return res.status(404).json({ error: `transaction ${a.transactionId} not found` });
      }
      const { amountDue } = summarizePayments(doc.toObject());
      if (amt > amountDue + 0.005) {
        return res.status(422).json({
          error: `Only ${amountDue.toFixed(2)} outstanding on one of the bills`,
          transactionId: a.transactionId,
          amountDue,
        });
      }
      const when = a.date ? new Date(a.date) : new Date();
      if (Number.isNaN(when.getTime())) {
        return res.status(400).json({ error: 'date is invalid' });
      }
      prepared.push({
        doc,
        amount: round2(amt),
        when,
        note: (a.note || '').toString().trim() || 'Party settlement',
      });
    }

    for (const p of prepared) {
      p.doc.payments.push({ amount: p.amount, date: p.when, note: p.note });
      await p.doc.save();
    }

    res.json({ ok: true, settled: prepared.length });
  })
);

module.exports = router;
