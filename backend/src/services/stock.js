// Single source of truth for stock math.
//
// Stock is a single pool: one running balance in grams plus a weighted-average
// cost per gram. It is derived by replaying every transaction in chronological
// order, so it can never drift from the ledger.
//
//   purchase of q grams @ rate r:  avg = (qty*avg + q*r) / (qty + q);  qty += q
//   sale     of q grams @ rate r:  qty -= q;  avg unchanged
//                                  costOfSale = q*avg;  profit = q*(r - avg)

const EPS = 1e-9;

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const round4 = (n) => Math.round((n + Number.EPSILON) * 10000) / 10000;

function sortChronologically(txns) {
  return [...txns].sort((a, b) => {
    const ad = new Date(a.date).getTime();
    const bd = new Date(b.date).getTime();
    if (ad !== bd) return ad - bd;
    const ac = new Date(a.createdAt || 0).getTime();
    const bc = new Date(b.createdAt || 0).getTime();
    if (ac !== bc) return ac - bc;
    return String(a._id).localeCompare(String(b._id));
  });
}

/**
 * @param {Array} txns  plain transaction objects ({ type, date, weightGrams, ratePerGram, createdAt, _id })
 * @returns {{
 *   weightGrams:number, avgCostPerGram:number, stockValue:number,
 *   realizedProfit:number, lastRatePerGram:number,
 *   perTxn: Map<string,{balanceAfter:number, avgCostAfter:number, profit:(number|null)}>
 * }}
 */
function replayStock(txns) {
  const ordered = sortChronologically(txns);

  let weightGrams = 0;
  let avgCostPerGram = 0;
  let realizedProfit = 0;
  const perTxn = new Map();

  for (const t of ordered) {
    let profit = null;

    if (t.type === 'purchase') {
      const nextWeight = weightGrams + t.weightGrams;
      avgCostPerGram =
        nextWeight > EPS
          ? (weightGrams * avgCostPerGram + t.weightGrams * t.ratePerGram) / nextWeight
          : 0;
      weightGrams = nextWeight;
    } else {
      profit = t.weightGrams * (t.ratePerGram - avgCostPerGram);
      realizedProfit += profit;
      weightGrams -= t.weightGrams;
      if (Math.abs(weightGrams) < EPS) weightGrams = 0;
    }

    perTxn.set(String(t._id), {
      balanceAfter: round4(weightGrams),
      avgCostAfter: round4(avgCostPerGram),
      profit: profit === null ? null : round2(profit),
    });
  }

  return {
    weightGrams: round4(weightGrams),
    avgCostPerGram: round2(avgCostPerGram),
    stockValue: round2(weightGrams * avgCostPerGram),
    realizedProfit: round2(realizedProfit),
    lastRatePerGram: ordered.length ? ordered[ordered.length - 1].ratePerGram : 0,
    perTxn,
  };
}

/** Grams currently on hand — used to validate sales. */
function availableWeight(txns) {
  return replayStock(txns).weightGrams;
}

module.exports = { replayStock, availableWeight, round2, round4 };
