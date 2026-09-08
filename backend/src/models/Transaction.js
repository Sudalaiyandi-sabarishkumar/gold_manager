const mongoose = require('mongoose');

const transactionSchema = new mongoose.Schema(
  {
    type: { type: String, enum: ['purchase', 'sale'], required: true },
    date: { type: Date, required: true },
    weightGrams: { type: Number, required: true, min: 0.0001 },
    ratePerGram: { type: Number, required: true, min: 0 },
    // Always computed server-side as weightGrams * ratePerGram; never trusted from the client.
    totalAmount: { type: Number, required: true, min: 0 },
    note: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

// Ledger is replayed in chronological order; index the sort keys.
transactionSchema.index({ date: 1, createdAt: 1 });

module.exports = mongoose.model('Transaction', transactionSchema);
