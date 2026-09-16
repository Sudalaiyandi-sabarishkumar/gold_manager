class Expense {
  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.note,
    this.createdAt,
  });

  final String id;
  final DateTime date;
  final double amount;
  final String note;
  final DateTime? createdAt;

  factory Expense.fromJson(Map<String, dynamic> j) => Expense(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        amount: (j['amount'] as num).toDouble(),
        note: (j['note'] as String?) ?? '',
        createdAt: j['createdAt'] != null
            ? DateTime.tryParse(j['createdAt'] as String)
            : null,
      );
}
