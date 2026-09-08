class GoldTransaction {
  const GoldTransaction({
    required this.id,
    required this.type,
    required this.date,
    required this.weightGrams,
    required this.ratePerGram,
    required this.totalAmount,
    required this.note,
    this.createdAt,
    this.balanceAfter,
    this.avgCostAfter,
    this.profit,
  });

  final String id;
  final String type; // 'purchase' | 'sale'
  final DateTime date;
  final double weightGrams;
  final double ratePerGram;
  final double totalAmount;
  final String note;
  final DateTime? createdAt;

  /// Stock in grams immediately after this transaction (from the server replay).
  final double? balanceAfter;
  final double? avgCostAfter;

  /// Realized profit for a sale; null for a purchase.
  final double? profit;

  bool get isPurchase => type == 'purchase';
  bool get isSale => type == 'sale';

  factory GoldTransaction.fromJson(Map<String, dynamic> j) => GoldTransaction(
        id: j['id'] as String,
        type: j['type'] as String,
        date: DateTime.parse(j['date'] as String),
        weightGrams: (j['weightGrams'] as num).toDouble(),
        ratePerGram: (j['ratePerGram'] as num).toDouble(),
        totalAmount: (j['totalAmount'] as num).toDouble(),
        note: (j['note'] as String?) ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
        balanceAfter: (j['balanceAfter'] as num?)?.toDouble(),
        avgCostAfter: (j['avgCostAfter'] as num?)?.toDouble(),
        profit: (j['profit'] as num?)?.toDouble(),
      );
}
