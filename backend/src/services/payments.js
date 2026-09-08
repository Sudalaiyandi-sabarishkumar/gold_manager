// Payment / settlement math, kept separate from stock math.
//
// A transaction's `totalAmount` is the invoice value. `payments` is the list of
// instalments actually settled. For a SALE the unpaid part is a receivable
// (the buyer owes us); for a PURCHASE it is a payable (we owe the seller).
// None of this affects stock or realized profit — those are booked on the gold
// weight at transaction time regardless of when cash moves.

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const EPS = 0.005;

function summarizePayments(txn) {
  const total = round2(txn.totalAmount || 0);
  const paid = round2((txn.payments || []).reduce((s, p) => s + (p.amount || 0), 0));
  const due = round2(Math.max(0, total - paid));

  let paymentStatus;
  if (due <= EPS) paymentStatus = 'paid';
  else if (paid <= EPS) paymentStatus = 'unpaid';
  else paymentStatus = 'partial';

  return { amountPaid: paid, amountDue: due, paymentStatus };
}

/**
 * Outstanding balances across all transactions, grouped by party.
 * @returns {{
 *   totalReceivable:number, totalPayable:number,
 *   receivables: Array<{party:string,totalDue:number,count:number,transactionIds:string[]}>,
 *   payables: Array<{party:string,totalDue:number,count:number,transactionIds:string[]}>
 * }}
 */
function outstanding(txns) {
  const receivablesByParty = new Map();
  const payablesByParty = new Map();
  let totalReceivable = 0;
  let totalPayable = 0;

  for (const t of txns) {
    const { amountDue } = summarizePayments(t);
    if (amountDue <= EPS) continue;

    const key = (t.party || '').trim() || 'Unnamed';
    const bucket = t.type === 'sale' ? receivablesByParty : payablesByParty;
    const entry =
      bucket.get(key) || { party: key, totalDue: 0, count: 0, transactionIds: [] };
    entry.totalDue = round2(entry.totalDue + amountDue);
    entry.count += 1;
    entry.transactionIds.push(String(t._id));
    bucket.set(key, entry);

    if (t.type === 'sale') totalReceivable = round2(totalReceivable + amountDue);
    else totalPayable = round2(totalPayable + amountDue);
  }

  const byDueDesc = (a, b) => b.totalDue - a.totalDue;
  return {
    totalReceivable,
    totalPayable,
    receivables: [...receivablesByParty.values()].sort(byDueDesc),
    payables: [...payablesByParty.values()].sort(byDueDesc),
  };
}

module.exports = { summarizePayments, outstanding, round2 };
