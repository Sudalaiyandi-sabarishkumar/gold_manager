const mongoose = require('mongoose');

// One instalment against a transaction's total. Embedded, so each gets its own _id.
const paymentSchema = new mongoose.Schema(
  {
    amount: { type: Number, required: true, min: 0.01 },
    date: { type: Date, required: true, default: Date.now },
    note: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

const transactionSchema = new mongoose.Schema(
  {
    // Owner — every transaction belongs to exactly one user.
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    type: { type: String, enum: ['purchase', 'sale'], required: true },
    date: { type: Date, required: true },
    // Buyer (on a sale) or seller (on a purchase). Used for name search and
    // per-person outstanding balances.
    party: { type: String, default: '', trim: true },
    weightGrams: { type: Number, required: true, min: 0.0001 },
    ratePerGram: { type: Number, required: true, min: 0 },
    // Always computed server-side as weightGrams * ratePerGram.
    totalAmount: { type: Number, required: true, min: 0 },
    note: { type: String, default: '', trim: true },
    // Cash actually settled so far. amountPaid = sum(payments.amount),
    // amountDue = totalAmount - amountPaid (all derived, never stored).
    payments: { type: [paymentSchema], default: [] },
  },
  { timestamps: true }
);

// Ledger is replayed in chronological order; index the sort keys.
transactionSchema.index({ userId: 1, date: 1, createdAt: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);
