const mongoose = require('mongoose');

// One settings document per user. _id is the user's ObjectId (as string) so
// there is no separate userId field needed — the document itself is the user.
const settingsSchema = new mongoose.Schema(
  {
    _id: { type: String }, // set to String(userId) on creation
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

/**
 * Return (or upsert) the settings document for a given userId.
 * Pass req.user.sub (the JWT subject, which equals String(user._id)).
 */
settingsSchema.statics.forUser = async function forUser(userId) {
  const id = String(userId);
  return (await this.findById(id)) || this.create({ _id: id });
};

module.exports = mongoose.model('Settings', settingsSchema);
