class StockSummary {
  const StockSummary({
    required this.weightGrams,
    required this.avgCostPerGram,
    required this.stockValue,
    required this.realizedProfit,
    required this.lastRatePerGram,
    required this.transactionCount,
    required this.totalReceivable,
    required this.totalPayable,
  });

  final double weightGrams;
  final double avgCostPerGram;
  final double stockValue;
  final double realizedProfit;
  final double lastRatePerGram;
  final int transactionCount;

  /// Buyers owe us this much (unpaid part of sales).
  final double totalReceivable;

  /// We owe sellers this much (unpaid part of purchases).
  final double totalPayable;

  static const StockSummary empty = StockSummary(
    weightGrams: 0,
    avgCostPerGram: 0,
    stockValue: 0,
    realizedProfit: 0,
    lastRatePerGram: 0,
    transactionCount: 0,
    totalReceivable: 0,
    totalPayable: 0,
  );

  factory StockSummary.fromJson(Map<String, dynamic> j) => StockSummary(
        weightGrams: (j['weightGrams'] as num).toDouble(),
        avgCostPerGram: (j['avgCostPerGram'] as num).toDouble(),
        stockValue: (j['stockValue'] as num).toDouble(),
        realizedProfit: (j['realizedProfit'] as num).toDouble(),
        lastRatePerGram: (j['lastRatePerGram'] as num).toDouble(),
        transactionCount: (j['transactionCount'] as num?)?.toInt() ?? 0,
        totalReceivable: (j['totalReceivable'] as num?)?.toDouble() ?? 0,
        totalPayable: (j['totalPayable'] as num?)?.toDouble() ?? 0,
      );
}
