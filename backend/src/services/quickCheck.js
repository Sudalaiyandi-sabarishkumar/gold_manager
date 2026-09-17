// Node port of the mobile Quick Check algorithm
// (mobile/lib/screens/quick_check_screen.dart QuickCheckResult.compute).
// Used ONLY to compute the "shrink" carry-forward seed server-side, so the
// backend is the authority on it rather than trusting a client-supplied
// number. Not exposed as a general-purpose endpoint.

/**
 * @param {Array} txns plain transaction objects ({ type, date, weightGrams, ratePerGram, totalAmount })
 * @param {{netQtyGrams?:number, carryRate?:number, saleRate?:number, purchasesTotal?:number, salesTotal?:number}} [seed]
 */
function replayQuickCheck(txns, seed = {}) {
  const tradeable = txns
    .filter((t) => t.type === 'purchase' || t.type === 'sale')
    .slice()
    .sort((a, b) => new Date(a.date) - new Date(b.date));

  let netQty = seed.netQtyGrams || 0;
  let carryRate = seed.carryRate || 0;
  let saleRate = seed.saleRate || 0;
  let purchasesTotal = seed.purchasesTotal || 0;
  let salesTotal = seed.salesTotal || 0;

  for (const t of tradeable) {
    const before = netQty;
    if (t.type === 'sale') {
      salesTotal += t.totalAmount;
      if (before < 0) {
        // Extending an existing demand: blend into the weighted-average
        // sale price that created it.
        const newWeight = before - t.weightGrams;
        saleRate =
          (Math.abs(before) * saleRate + t.weightGrams * t.ratePerGram) /
          (Math.abs(before) + t.weightGrams);
        netQty = newWeight;
      } else {
        // before >= 0: starting fresh, or (partially or fully) covering an
        // excess. Any sale here resets saleRate to its own price.
        saleRate = t.ratePerGram;
        netQty = before - t.weightGrams;
      }
      // A sale never touches carryRate.
    } else {
      purchasesTotal += t.totalAmount;
      if (before > 0) {
        const newWeight = before + t.weightGrams;
        carryRate = (before * carryRate + t.weightGrams * t.ratePerGram) / newWeight;
        netQty = newWeight;
      } else {
        carryRate = t.ratePerGram;
        netQty = before + t.weightGrams;
      }
      // A purchase never touches saleRate.
    }
  }

  // Project closing the remaining position at whichever rate actually
  // applies: carryRate while in excess, saleRate while in demand.
  const applicableRate = netQty > 0 ? carryRate : netQty < 0 ? saleRate : 0;
  const profit = salesTotal - purchasesTotal + netQty * applicableRate;

  return { netQtyGrams: netQty, carryRate, saleRate, purchasesTotal, salesTotal, profit };
}

function quickCheckSeedFromSettings(s) {
  return {
    netQtyGrams: s.quickCheckSeedNetQtyGrams || 0,
    carryRate: s.quickCheckSeedCarryRate || 0,
    saleRate: s.quickCheckSeedSaleRate || 0,
    purchasesTotal: s.quickCheckSeedPurchasesTotal || 0,
    salesTotal: s.quickCheckSeedSalesTotal || 0,
  };
}

module.exports = { replayQuickCheck, quickCheckSeedFromSettings };
