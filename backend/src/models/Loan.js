const mongoose = require('mongoose');

const repaymentSchema = new mongoose.Schema(
  {
    date: { type: Date, required: true },
    principalReturned: { type: Number, required: true, min: 0 },
    interestPaid: { type: Number, required: true, min: 0 },
    note: { type: String, default: '', trim: true },
  },
  { _id: false }
);

// A loan given out, in cash (principal/interest in rupees) or gold (in grams).
//   interest per period = principal / interestRefAmount * interestRate
//   e.g. cash: 100 per 'day' per 100000   |   gold: 1.5 per 'month' per 100
const loanSchema = new mongoose.Schema(
  {
    kind: { type: String, enum: ['cash', 'gold'], required: true },
    party: { type: String, default: '', trim: true }, // borrower
    date: { type: Date, required: true },
    principal: { type: Number, required: true, min: 0.0001 },
    interestRate: { type: Number, required: true, min: 0 },
    interestRefAmount: { type: Number, required: true, min: 0.0001 },
    interestUnit: { type: String, enum: ['day', 'month'], required: true },
    // Whether the day the loan was given counts as a full period.
    countStartDay: { type: Boolean, default: false },
    note: { type: String, default: '', trim: true },
    // null while open; set on repayment.
    repayment: { type: repaymentSchema, default: null },
  },
  { timestamps: true }
);

loanSchema.index({ date: 1, createdAt: 1 });

module.exports = mongoose.model('Loan', loanSchema);
