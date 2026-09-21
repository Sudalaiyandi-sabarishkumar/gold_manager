const mongoose = require('mongoose');

// A miscellaneous cash withdrawal — money taken out of hand for something
// other than a gold purchase, sale, or loan (e.g. personal use, shop rent).
const expenseSchema = new mongoose.Schema(
  {
    // Owner — every expense belongs to exactly one user.
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    date: { type: Date, required: true },
    amount: { type: Number, required: true, min: 0.01 },
    note: { type: String, default: '', trim: true },
  },
  { timestamps: true }
);

expenseSchema.index({ userId: 1, date: 1, createdAt: 1 });

module.exports = mongoose.model('Expense', expenseSchema);
