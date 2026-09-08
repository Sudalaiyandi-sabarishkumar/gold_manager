class Payment {
  const Payment({
    required this.id,
    required this.amount,
    required this.date,
    required this.note,
  });

  final String id;
  final double amount;
  final DateTime date;
  final String note;

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        amount: (j['amount'] as num).toDouble(),
        date: DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
      );
}

class GoldTransaction {
  const GoldTransaction({
    required this.id,
    required this.type,
    required this.date,
    required this.party,
    required this.weightGrams,
    required this.ratePerGram,
    required this.totalAmount,
    required this.note,
    required this.amountPaid,
    required this.amountDue,
    required this.paymentStatus,
    required this.payments,
    this.createdAt,
    this.balanceAfter,
    this.avgCostAfter,
    this.profit,
  });

  final String id;
  final String type; // 'purchase' | 'sale'
  final DateTime date;
  final String party; // buyer (sale) / seller (purchase)
  final double weightGrams;
  final double ratePerGram;
  final double totalAmount;
  final String note;
  final DateTime? createdAt;

  // Stock in grams immediately after this transaction (server replay).
  final double? balanceAfter;
  final double? avgCostAfter;

  // Realized profit for a sale; null for a purchase.
  final double? profit;

  // Settlement (server-derived).
  final double amountPaid;
  final double amountDue;
  final String paymentStatus; // 'paid' | 'partial' | 'unpaid'
  final List<Payment> payments;

  bool get isPurchase => type == 'purchase';
  bool get isSale => type == 'sale';
  bool get isSettled => paymentStatus == 'paid';

  /// "Buyer" for a sale, "Seller" for a purchase.
  String get partyRole => isSale ? 'Buyer' : 'Seller';

  factory GoldTransaction.fromJson(Map<String, dynamic> j) => GoldTransaction(
        id: j['id'] as String,
        type: j['type'] as String,
        date: DateTime.parse(j['date'] as String),
        party: (j['party'] as String?) ?? '',
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
        amountPaid: (j['amountPaid'] as num?)?.toDouble() ?? 0,
        amountDue: (j['amountDue'] as num?)?.toDouble() ?? 0,
        paymentStatus: (j['paymentStatus'] as String?) ?? 'paid',
        payments: ((j['payments'] as List<dynamic>?) ?? const [])
            .map((e) => Payment.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
