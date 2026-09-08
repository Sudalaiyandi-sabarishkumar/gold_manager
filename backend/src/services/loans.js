// Loan interest maths, kept pure and separate.
//
// Interest per period = principal / interestRefAmount * interestRate
// Periods elapsed     = elapsed days (+1 if countStartDay) / (unit === 'month' ? 30 : 1)
// A gold loan's principal and interest are grams; a cash loan's are rupees.

const round2 = (n) => Math.round((n + Number.EPSILON) * 100) / 100;
const round4 = (n) => Math.round((n + Number.EPSILON) * 10000) / 10000;
const DAY_MS = 86400000;

const startOfDay = (d) => {
  const x = new Date(d);
  x.setHours(0, 0, 0, 0);
  return x;
};

const roundFor = (kind, n) => (kind === 'gold' ? round4(n) : round2(n));

function daysElapsed(loan, asOf) {
  let days = Math.floor((startOfDay(asOf) - startOfDay(loan.date)) / DAY_MS);
  if (loan.countStartDay) days += 1;
  return days < 0 ? 0 : days;
}

function periodsElapsed(loan, asOf) {
  const perLen = loan.interestUnit === 'month' ? 30 : 1;
  return daysElapsed(loan, asOf) / perLen;
}

function accruedInterest(loan, asOf) {
  const raw =
    (loan.principal / loan.interestRefAmount) *
    loan.interestRate *
    periodsElapsed(loan, asOf);
  return roundFor(loan.kind, raw);
}

function serializeLoan(loan, asOf = new Date()) {
  const repaid = Boolean(loan.repayment);
  const accrued = repaid ? loan.repayment.interestPaid : accruedInterest(loan, asOf);
  const outstanding = repaid
    ? 0
    : roundFor(loan.kind, loan.principal + accrued);

  return {
    id: String(loan._id),
    kind: loan.kind,
    party: loan.party || '',
    date: loan.date,
    principal: loan.principal,
    interestRate: loan.interestRate,
    interestRefAmount: loan.interestRefAmount,
    interestUnit: loan.interestUnit,
    countStartDay: loan.countStartDay,
    note: loan.note || '',
    createdAt: loan.createdAt,
    status: repaid ? 'repaid' : 'open',
    daysElapsed: daysElapsed(loan, asOf),
    accruedInterest: accrued,
    outstanding,
    repayment: repaid
      ? {
          date: loan.repayment.date,
          principalReturned: loan.repayment.principalReturned,
          interestPaid: loan.repayment.interestPaid,
          note: loan.repayment.note || '',
        }
      : null,
  };
}

module.exports = { accruedInterest, serializeLoan, daysElapsed, roundFor, round2, round4 };
