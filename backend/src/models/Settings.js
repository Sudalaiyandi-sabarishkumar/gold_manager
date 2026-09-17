const mongoose = require('mongoose');

// Single document: the opening position everything is computed from.
const settingsSchema = new mongoose.Schema(
  {
    _id: { type: String, default: 'app' },
    openingCash: { type: Number, default: 1500000, min: 0 },
    openingGoldGrams: { type: Number, default: 100, min: 0 },

    // --- Shrink carry-forward seeds. Only ever written by
    // POST /api/transactions/shrink; never accepted by PUT /api/settings. ---
    cashSeed: { type: Number, default: 0 },
    stockSeedWeightGrams: { type: Number, default: 0 },
    stockSeedAvgCostPerGram: { type: Number, default: 0, min: 0 },
    stockSeedRealizedProfit: { type: Number, default: 0 },
    quickCheckSeedNetQtyGrams: { type: Number, default: 0 },
    quickCheckSeedCarryRate: { type: Number, default: 0, min: 0 },
    quickCheckSeedSaleRate: { type: Number, default: 0, min: 0 },
    quickCheckSeedPurchasesTotal: { type: Number, default: 0, min: 0 },
    quickCheckSeedSalesTotal: { type: Number, default: 0, min: 0 },
    shrunkThroughDate: { type: Date, default: null },
  },
  { timestamps: true }
);

settingsSchema.statics.current = async function current() {
  return (await this.findById('app')) || this.create({ _id: 'app' });
};

module.exports = mongoose.model('Settings', settingsSchema);
