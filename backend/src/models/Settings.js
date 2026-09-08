const mongoose = require('mongoose');

// Single document: the opening position everything is computed from.
const settingsSchema = new mongoose.Schema(
  {
    _id: { type: String, default: 'app' },
    openingCash: { type: Number, default: 1500000, min: 0 },
    openingGoldGrams: { type: Number, default: 100, min: 0 },
  },
  { timestamps: true }
);

settingsSchema.statics.current = async function current() {
  return (await this.findById('app')) || this.create({ _id: 'app' });
};

module.exports = mongoose.model('Settings', settingsSchema);
