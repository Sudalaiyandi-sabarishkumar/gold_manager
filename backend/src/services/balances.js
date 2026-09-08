// The unified position: cash in hand and gold in stock, with every event
// (opening balance, purchase, sale, bill payment, loan given, loan repaid)
// flowing through both.
//
// Weighted-average cost and realized trade profit still come from purchases
// and sales only (see services/stock.js); opening gold is carried at that
// average for a rough stock valuation.

const { replayStock } = require('./stock');
const { accruedInterest } = require('./loans');

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const round4 = (n) => Math.round((n + Number.EPSILON) * 10000) / 10000;

const paidOn = (txn) => (txn.payments || []).reduce((s, p) => s + (p.amount || 0), 0);

function computeBalances({ openingCash, openingGoldGrams, transactions, loans, asOf = new Date() }) {
  const trade = replayStock(transactions);

  let cash = openingCash;
  let gold = openingGoldGrams + trade.weightGrams;

  for (const t of transactions) {
    const paid = paidOn(t);
    if (t.type === 'sale') cash += paid;
    else cash -= paid;
  }

  let loanCashPrincipal = 0;
  let loanCashInterest = 0;
  let loanGoldPrincipal = 0;
  let loanGoldInterest = 0;
  let interestEarnedCash = 0;
  let interestEarnedGold = 0;

  for (const ln of loans) {
    // principal left when the loan was given
    if (ln.kind === 'cash') cash -= ln.principal;
    else gold -= ln.principal;

    if (ln.repayment) {
      const back = (ln.repayment.principalReturned || 0) + (ln.repayment.interestPaid || 0);
      if (ln.kind === 'cash') {
        cash += back;
        interestEarnedCash += ln.repayment.interestPaid || 0;
      } else {
        gold += back;
        interestEarnedGold += ln.repayment.interestPaid || 0;
      }
    } else {
      const accrued = accruedInterest(ln, asOf);
      if (ln.kind === 'cash') {
        loanCashPrincipal += ln.principal;
        loanCashInterest += accrued;
      } else {
        loanGoldPrincipal += ln.principal;
        loanGoldInterest += accrued;
      }
    }
  }

  return {
    openingCash: round2(openingCash),
    openingGoldGrams: round4(openingGoldGrams),

    cashInHand: round2(cash),
    goldInStockGrams: round4(gold),
    avgCostPerGram: trade.avgCostPerGram,
    goldStockValue: round2(gold * trade.avgCostPerGram),
    tradeRealizedProfit: trade.realizedProfit,

    loanCashPrincipal: round2(loanCashPrincipal),
    loanCashInterestAccrued: round2(loanCashInterest),
    loanCashOutstanding: round2(loanCashPrincipal + loanCashInterest),
    loanGoldPrincipalGrams: round4(loanGoldPrincipal),
    loanGoldInterestAccruedGrams: round4(loanGoldInterest),
    loanGoldOutstandingGrams: round4(loanGoldPrincipal + loanGoldInterest),

    interestEarnedCash: round2(interestEarnedCash),
    interestEarnedGoldGrams: round4(interestEarnedGold),
  };
}

module.exports = { computeBalances };
