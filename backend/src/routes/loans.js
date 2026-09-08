const express = require('express');
const mongoose = require('mongoose');
const Loan = require('../models/Loan');
const Transaction = require('../models/Transaction');
const Settings = require('../models/Settings');
const { serializeLoan, accruedInterest, roundFor } = require('../services/loans');
const { computeBalances } = require('../services/balances');
const ah = require('../lib/asyncHandler');

const router = express.Router();

async function available(kind) {
  const [s, transactions, loans] = await Promise.all([
    Settings.current(),
    Transaction.find().lean(),
    Loan.find().lean(),
  ]);
  const b = computeBalances({
    openingCash: s.openingCash,
    openingGoldGrams: s.openingGoldGrams,
    transactions,
    loans,
  });
  return kind === 'cash' ? b.cashInHand : b.goldInStockGrams;
}

// GET /api/loans?status=open|repaid&kind=cash|gold&q=<borrower/note>
router.get(
  '/',
  ah(async (req, res) => {
    const loans = await Loan.find().sort({ date: -1, createdAt: -1 }).lean();
    let list = loans.map((l) => serializeLoan(l));

    const { status, kind, q } = req.query;
    if (status === 'open' || status === 'repaid') list = list.filter((l) => l.status === status);
    if (kind === 'cash' || kind === 'gold') list = list.filter((l) => l.kind === kind);
    if (q && q.trim()) {
      const needle = q.trim().toLowerCase();
      list = list.filter(
        (l) =>
          (l.party || '').toLowerCase().includes(needle) ||
          (l.note || '').toLowerCase().includes(needle)
      );
    }
    res.json(list);
  })
);

// GET /api/loans/:id
router.get(
  '/:id',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const loan = await Loan.findById(req.params.id).lean();
    if (!loan) return res.status(404).json({ error: 'Not found' });
    res.json(serializeLoan(loan));
  })
);

// POST /api/loans
router.post(
  '/',
  ah(async (req, res) => {
    const {
      kind,
      party,
      date,
      principal,
      interestRate,
      interestRefAmount,
      interestUnit,
      countStartDay,
      note,
    } = req.body || {};

    if (kind !== 'cash' && kind !== 'gold') {
      return res.status(400).json({ error: "kind must be 'cash' or 'gold'" });
    }
    if (interestUnit !== 'day' && interestUnit !== 'month') {
      return res.status(400).json({ error: "interestUnit must be 'day' or 'month'" });
    }
    const p = Number(principal);
    const rate = Number(interestRate);
    const ref = Number(interestRefAmount);
    if (!(p > 0)) return res.status(400).json({ error: 'principal must be greater than 0' });
    if (!(rate >= 0)) return res.status(400).json({ error: 'interestRate must be 0 or more' });
    if (!(ref > 0)) return res.status(400).json({ error: 'interestRefAmount must be greater than 0' });

    const when = date ? new Date(date) : new Date();
    if (Number.isNaN(when.getTime())) return res.status(400).json({ error: 'date is invalid' });

    const have = await available(kind);
    if (p > have + 1e-6) {
      return res.status(422).json({
        error:
          kind === 'cash'
            ? `Only ₹${have.toFixed(2)} cash in hand`
            : `Only ${have.toFixed(2)} g in stock`,
        available: have,
      });
    }

    const loan = await Loan.create({
      kind,
      party: (party || '').toString().trim(),
      date: when,
      principal: p,
      interestRate: rate,
      interestRefAmount: ref,
      interestUnit,
      countStartDay: Boolean(countStartDay),
      note: (note || '').toString().trim(),
    });
    res.status(201).json(serializeLoan(loan.toObject()));
  })
);

// POST /api/loans/:id/repay  { date?, principalReturned?, interestPaid?, note? }
router.post(
  '/:id/repay',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const loan = await Loan.findById(req.params.id);
    if (!loan) return res.status(404).json({ error: 'Not found' });
    if (loan.repayment) return res.status(409).json({ error: 'Loan is already repaid' });

    const when = req.body && req.body.date ? new Date(req.body.date) : new Date();
    if (Number.isNaN(when.getTime())) return res.status(400).json({ error: 'date is invalid' });

    const interestPaid =
      req.body && req.body.interestPaid !== undefined && req.body.interestPaid !== null
        ? Number(req.body.interestPaid)
        : accruedInterest(loan.toObject(), when);
    const principalReturned =
      req.body && req.body.principalReturned !== undefined && req.body.principalReturned !== null
        ? Number(req.body.principalReturned)
        : loan.principal;

    if (!(interestPaid >= 0)) return res.status(400).json({ error: 'interestPaid must be 0 or more' });
    if (!(principalReturned >= 0)) {
      return res.status(400).json({ error: 'principalReturned must be 0 or more' });
    }

    loan.repayment = {
      date: when,
      principalReturned: roundFor(loan.kind, principalReturned),
      interestPaid: roundFor(loan.kind, interestPaid),
      note: ((req.body && req.body.note) || '').toString().trim(),
    };
    await loan.save();
    res.json(serializeLoan(loan.toObject()));
  })
);

// DELETE /api/loans/:id/repay  -> reopen
router.delete(
  '/:id/repay',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const loan = await Loan.findById(req.params.id);
    if (!loan) return res.status(404).json({ error: 'Not found' });
    loan.repayment = null;
    await loan.save();
    res.json(serializeLoan(loan.toObject()));
  })
);

// DELETE /api/loans/:id
router.delete(
  '/:id',
  ah(async (req, res) => {
    if (!mongoose.isValidObjectId(req.params.id)) {
      return res.status(404).json({ error: 'Not found' });
    }
    const deleted = await Loan.findByIdAndDelete(req.params.id);
    if (!deleted) return res.status(404).json({ error: 'Not found' });
    res.json({ ok: true });
  })
);

module.exports = router;
