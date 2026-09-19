const express = require('express');
const mongoose = require('mongoose');
const Transaction = require('../models/Transaction');
const Loan = require('../models/Loan');
const Settings = require('../models/Settings');
const { replayStock, stockSeedFromSettings, sortChronologically } = require('../services/stock');
const { summarizePayments, round2 } = require('../services/payments');
const { computeBalances, balanceSeedFromSettings, paidOn } = require('../services/balances');
const {
  replayQuickCheck,
  quickCheckSeedFromSettings,
  safePriceFor,
} = require('../services/quickCheck');
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
    const [settings, all] = await Promise.all([Settings.current(), Transaction.find().lean()]);
    const { perTxn } = replayStock(all, stockSeedFromSettings(settings));

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
    const [settings, all] = await Promise.all([Settings.current(), Transaction.find().lean()]);
    const { perTxn } = replayStock(all, stockSeedFromSettings(settings));
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

    const settings = await Settings.current();

    if (settings.shrunkThroughDate && when < settings.shrunkThroughDate) {
      return res.status(422).json({
        error: `Cannot backdate before ${settings.shrunkThroughDate
          .toISOString()
          .slice(0, 10)} — that history has been shrunk.`,
        shrunkThroughDate: settings.shrunkThroughDate,
      });
    }

    if (type === 'sale') {
      const [all, loans] = await Promise.all([Transaction.find().lean(), Loan.find().lean()]);
      const available = computeBalances({
        openingCash: settings.openingCash,
        openingGoldGrams: settings.openingGoldGrams,
        ...balanceSeedFromSettings(settings),
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
    const { perTxn } = replayStock(all, stockSeedFromSettings(settings));
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

    const [settings, all] = await Promise.all([Settings.current(), Transaction.find().lean()]);
    const { perTxn } = replayStock(all, stockSeedFromSettings(settings));
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

    const [settings, all] = await Promise.all([Settings.current(), Transaction.find().lean()]);
    const { perTxn } = replayStock(all, stockSeedFromSettings(settings));
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

// POST /api/transactions/shrink  { confirm: true }
//
// Deletes every fully-paid transaction dated up through today, stopping
// early at the oldest still-pending (unpaid or partial) transaction if
// there is one — a pending entry is never deleted, no matter how old, and
// nothing dated after it gets deleted either (even later fully-paid
// entries), to keep this a safe, contiguous prefix. Cash, gold, avg cost,
// realized profit, receivable/payable and Quick Check are all unaffected
// by design — see services/stock.js, services/balances.js,
// services/quickCheck.js and Settings' seed fields for how.
router.post(
  '/shrink',
  ah(async (req, res) => {
    if (!req.body || req.body.confirm !== true) {
      return res.status(400).json({ error: 'confirm must be true' });
    }

    const settings = await Settings.current();
    const all = await Transaction.find().lean();
    const ordered = sortChronologically(all);

    const now = new Date();

    // Walk oldest-first; stop at the first transaction that is either
    // still pending, or dated after "now" (a backdate-guard edge case) —
    // everything before that point is a safe, contiguous prefix to fold away.
    let boundaryIndex = ordered.length;
    for (let i = 0; i < ordered.length; i++) {
      const t = ordered[i];
      const isPending = summarizePayments(t).paymentStatus !== 'paid';
      const isFuture = new Date(t.date) > now;
      if (isPending || isFuture) {
        boundaryIndex = i;
        break;
      }
    }

    const prefix = ordered.slice(0, boundaryIndex);
    const kept = ordered.slice(boundaryIndex);

    if (prefix.length === 0) {
      return res.json({
        ok: true,
        deletedCount: 0,
        remainingCount: ordered.length,
        message:
          ordered.length === 0
            ? 'No transactions to shrink.'
            : 'The oldest transaction is still pending — nothing to shrink yet.',
      });
    }

    const stockAfterPrefix = replayStock(prefix, stockSeedFromSettings(settings));
    const qcAfterPrefix = replayQuickCheck(prefix, quickCheckSeedFromSettings(settings));

    let cashDelta = 0;
    for (const t of prefix) {
      const paid = paidOn(t);
      cashDelta += t.type === 'sale' ? paid : -paid;
    }

    // Persist the new seeds FIRST. If the delete below fails partway, the
    // failure is loud (remaining prefix rows would be double-counted on the
    // next read) rather than silent — recoverable by deleting exactly
    // `remainingPrefixIds` directly, without calling shrink again.
    settings.stockSeedWeightGrams = stockAfterPrefix.weightGrams;
    settings.stockSeedAvgCostPerGram = stockAfterPrefix.avgCostPerGram;
    settings.stockSeedRealizedProfit = stockAfterPrefix.realizedProfit;
    settings.quickCheckSeedNetQtyGrams = qcAfterPrefix.netQtyGrams;
    settings.quickCheckSeedCarryRate = qcAfterPrefix.carryRate;
    settings.quickCheckSeedSaleRate = qcAfterPrefix.saleRate;
    settings.quickCheckSeedPurchasesTotal = qcAfterPrefix.purchasesTotal;
    settings.quickCheckSeedSalesTotal = qcAfterPrefix.salesTotal;
    settings.cashSeed = round2((settings.cashSeed || 0) + cashDelta);
    const newBoundaryDate = prefix[prefix.length - 1].date;
    if (
      !settings.shrunkThroughDate ||
      new Date(newBoundaryDate) > new Date(settings.shrunkThroughDate)
    ) {
      settings.shrunkThroughDate = newBoundaryDate;
    }
    await settings.save();

    const prefixIds = prefix.map((t) => t._id);
    const del = await Transaction.deleteMany({ _id: { $in: prefixIds } });

    if (del.deletedCount !== prefixIds.length) {
      return res.status(500).json({
        error:
          'Shrink partially failed: settings were updated but not all transactions were removed. ' +
          'Do not call shrink again — delete the listed ids directly instead.',
        expectedDeleted: prefixIds.length,
        actuallyDeleted: del.deletedCount,
        remainingPrefixIds: prefixIds.map(String),
      });
    }

    res.json({
      ok: true,
      deletedCount: prefixIds.length,
      remainingCount: kept.length,
      boundaryDate: kept.length ? kept[0].date : null,
    });
  })
);

// POST /api/transactions/refresh  { confirm: true }
//
// A harder reset than shrink: wipes the ENTIRE transaction history (not just
// a safe prefix — pending entries included), resets opening balance to a
// fixed 7,500,000 cash / 100g gold, and zeroes every carry-forward seed
// (stock, cash, Quick Check, shrunk-through date). Unlike shrink, In Hand
// and Quick Check are NOT preserved as-is — they reset to the fixed opening
// balance, except that whatever excess/demand Quick Check showed *right
// before* the wipe is re-created as a single synthetic transaction dated
// today, fully paid, so that one number survives the reset:
//   - Excess (net position > 0): a 'sale' of the excess weight, at the
//     "safe to sell above" price, party "Excess".
//   - Demand (net position < 0): a 'purchase' of the demand weight, at the
//     "safe to buy below" price, party "Demand".
//   - Balanced (net position 0): nothing is created.
router.post(
  '/refresh',
  ah(async (req, res) => {
    if (!req.body || req.body.confirm !== true) {
      return res.status(400).json({ error: 'confirm must be true' });
    }

    const settings = await Settings.current();
    const all = await Transaction.find().lean();

    const qc = replayQuickCheck(all, quickCheckSeedFromSettings(settings));
    const netQty = qc.netQtyGrams;
    const computedSafePrice = safePriceFor(netQty, qc.carryRate, qc.saleRate);
    const hasPosition = Math.abs(netQty) > 1e-9;

    // Use the client-supplied rate for the carry-forward transaction when
    // there IS a position to carry forward; falls back to the computed
    // safe price if none was supplied. Rejects a non-positive rate outright
    // rather than silently substituting something else.
    let rate = computedSafePrice;
    if (hasPosition && req.body.rate !== undefined && req.body.rate !== null) {
      const r = Number(req.body.rate);
      if (!(r > 0)) {
        return res.status(400).json({ error: 'rate must be greater than 0' });
      }
      rate = r;
    }

    await Transaction.deleteMany({});

    settings.openingCash = 7500000;
    settings.openingGoldGrams = 500;
    settings.cashSeed = 0;
    settings.stockSeedWeightGrams = 0;
    settings.stockSeedAvgCostPerGram = 0;
    settings.stockSeedRealizedProfit = 0;
    settings.quickCheckSeedNetQtyGrams = 0;
    settings.quickCheckSeedCarryRate = 0;
    settings.quickCheckSeedSaleRate = 0;
    settings.quickCheckSeedPurchasesTotal = 0;
    settings.quickCheckSeedSalesTotal = 0;
    settings.shrunkThroughDate = undefined;
    await settings.save();

    let created = null;
    if (hasPosition) {
      const today = new Date();
      const isExcess = netQty > 0;
      const weight = Math.abs(netQty);
      const total = round2(weight * rate);

      const doc = await Transaction.create({
        type: isExcess ? 'purchase' : 'sale',
        date: today,
        party: isExcess ? 'Excess' : 'Demand',
        weightGrams: weight,
        ratePerGram: rate,
        totalAmount: total,
        note: 'Created by refresh',
        payments: total > 0 ? [{ amount: total, date: today, note: 'Refresh carry-forward' }] : [],
      });

      const { perTxn } = replayStock([doc.toObject()], stockSeedFromSettings(settings));
      created = serialize(doc.toObject(), perTxn);
    }

    res.json({
      ok: true,
      previousPosition: {
        netQtyGrams: netQty,
        status: netQty > 1e-9 ? 'excess' : netQty < -1e-9 ? 'demand' : 'balanced',
        safePrice: computedSafePrice,
        rateUsed: hasPosition ? rate : null,
      },
      createdTransaction: created,
    });
  })
);


module.exports = router;
