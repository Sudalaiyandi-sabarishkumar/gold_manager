const express = require('express');
const Settings = require('../models/Settings');
const ah = require('../lib/asyncHandler');

const router = express.Router();

// cashSeed/stockSeed*/shrunkThroughDate are deliberately NOT exposed here —
// the mobile app never replays stock itself, it only displays /api/stock's
// output, so it has no use for them. quickCheckSeed* IS exposed because
// Quick Check's algorithm runs client-side and needs a starting point after
// a shrink.
const shape = (s) => ({
  openingCash: s.openingCash,
  openingGoldGrams: s.openingGoldGrams,
  quickCheckSeedNetQtyGrams: s.quickCheckSeedNetQtyGrams || 0,
  quickCheckSeedCarryRate: s.quickCheckSeedCarryRate || 0,
  quickCheckSeedSaleRate: s.quickCheckSeedSaleRate || 0,
  quickCheckSeedPurchasesTotal: s.quickCheckSeedPurchasesTotal || 0,
  quickCheckSeedSalesTotal: s.quickCheckSeedSalesTotal || 0,
});

// GET /api/settings
router.get(
  '/',
  ah(async (req, res) => {
    res.json(shape(await Settings.current()));
  })
);

// PUT /api/settings  { openingCash?, openingGoldGrams? }
router.put(
  '/',
  ah(async (req, res) => {
    const s = await Settings.current();
    const { openingCash, openingGoldGrams } = req.body || {};

    if (openingCash !== undefined) {
      const v = Number(openingCash);
      if (!(v >= 0)) return res.status(400).json({ error: 'openingCash must be 0 or more' });
      s.openingCash = v;
    }
    if (openingGoldGrams !== undefined) {
      const v = Number(openingGoldGrams);
      if (!(v >= 0)) return res.status(400).json({ error: 'openingGoldGrams must be 0 or more' });
      s.openingGoldGrams = v;
    }
    await s.save();
    res.json(shape(s));
  })
);

module.exports = router;
