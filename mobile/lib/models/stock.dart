class StockSummary {
  const StockSummary({
    required this.cashInHand,
    required this.weightGrams,
    required this.openingCash,
    required this.openingGoldGrams,
    required this.avgCostPerGram,
    required this.stockValue,
    required this.realizedProfit,
    required this.lastRatePerGram,
    required this.transactionCount,
    required this.totalReceivable,
    required this.totalPayable,
    required this.loanCashPrincipal,
    required this.loanCashInterestAccrued,
    required this.loanCashOutstanding,
    required this.loanGoldPrincipalGrams,
    required this.loanGoldInterestAccruedGrams,
    required this.loanGoldOutstandingGrams,
    required this.interestEarnedCash,
    required this.interestEarnedGoldGrams,
  });

  // Physical position
  final double cashInHand;
  final double weightGrams; // gold physically in stock
  final double openingCash;
  final double openingGoldGrams;

  // Trade valuation / P&L
  final double avgCostPerGram;
  final double stockValue;
  final double realizedProfit;
  final double lastRatePerGram;
  final int transactionCount;

  // Trade dues (bills)
  final double totalReceivable;
  final double totalPayable;

  // Loans given out
  final double loanCashPrincipal;
  final double loanCashInterestAccrued;
  final double loanCashOutstanding;
  final double loanGoldPrincipalGrams;
  final double loanGoldInterestAccruedGrams;
  final double loanGoldOutstandingGrams;
  final double interestEarnedCash;
  final double interestEarnedGoldGrams;

  static const StockSummary empty = StockSummary(
    cashInHand: 0,
    weightGrams: 0,
    openingCash: 0,
    openingGoldGrams: 0,
    avgCostPerGram: 0,
    stockValue: 0,
    realizedProfit: 0,
    lastRatePerGram: 0,
    transactionCount: 0,
    totalReceivable: 0,
    totalPayable: 0,
    loanCashPrincipal: 0,
    loanCashInterestAccrued: 0,
    loanCashOutstanding: 0,
    loanGoldPrincipalGrams: 0,
    loanGoldInterestAccruedGrams: 0,
    loanGoldOutstandingGrams: 0,
    interestEarnedCash: 0,
    interestEarnedGoldGrams: 0,
  );

  static double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

  factory StockSummary.fromJson(Map<String, dynamic> j) => StockSummary(
        cashInHand: _d(j['cashInHand']),
        weightGrams: _d(j['weightGrams']),
        openingCash: _d(j['openingCash']),
        openingGoldGrams: _d(j['openingGoldGrams']),
        avgCostPerGram: _d(j['avgCostPerGram']),
        stockValue: _d(j['stockValue']),
        realizedProfit: _d(j['realizedProfit']),
        lastRatePerGram: _d(j['lastRatePerGram']),
        transactionCount: (j['transactionCount'] as num?)?.toInt() ?? 0,
        totalReceivable: _d(j['totalReceivable']),
        totalPayable: _d(j['totalPayable']),
        loanCashPrincipal: _d(j['loanCashPrincipal']),
        loanCashInterestAccrued: _d(j['loanCashInterestAccrued']),
        loanCashOutstanding: _d(j['loanCashOutstanding']),
        loanGoldPrincipalGrams: _d(j['loanGoldPrincipalGrams']),
        loanGoldInterestAccruedGrams: _d(j['loanGoldInterestAccruedGrams']),
        loanGoldOutstandingGrams: _d(j['loanGoldOutstandingGrams']),
        interestEarnedCash: _d(j['interestEarnedCash']),
        interestEarnedGoldGrams: _d(j['interestEarnedGoldGrams']),
      );
}
