import '../utils/format.dart';

class LoanRepayment {
  const LoanRepayment({
    required this.date,
    required this.principalReturned,
    required this.interestPaid,
    required this.note,
  });

  final DateTime date;
  final double principalReturned;
  final double interestPaid;
  final String note;

  factory LoanRepayment.fromJson(Map<String, dynamic> j) => LoanRepayment(
        date: DateTime.parse(j['date'] as String),
        principalReturned: (j['principalReturned'] as num).toDouble(),
        interestPaid: (j['interestPaid'] as num).toDouble(),
        note: (j['note'] as String?) ?? '',
      );
}

class Loan {
  const Loan({
    required this.id,
    required this.kind,
    required this.party,
    required this.date,
    required this.principal,
    required this.interestRate,
    required this.interestRefAmount,
    required this.interestUnit,
    required this.countStartDay,
    required this.note,
    required this.status,
    required this.daysElapsed,
    required this.accruedInterest,
    required this.outstanding,
    this.repayment,
  });

  final String id;
  final String kind; // 'cash' | 'gold'
  final String party; // borrower
  final DateTime date;
  final double principal;
  final double interestRate;
  final double interestRefAmount;
  final String interestUnit; // 'day' | 'month'
  final bool countStartDay;
  final String note;
  final String status; // 'open' | 'repaid'
  final int daysElapsed;
  final double accruedInterest;
  final double outstanding;
  final LoanRepayment? repayment;

  bool get isCash => kind == 'cash';
  bool get isGold => kind == 'gold';
  bool get isOpen => status == 'open';

  /// Format an amount in this loan's units (₹ for cash, g for gold).
  String amount(num n) => isCash ? inr(n) : grams(n);
  String amount2(num n) => isCash ? inr2(n) : grams(n);

  /// "₹100 / day per ₹1,00,000"  or  "1.50 g / month per 100.00 g"
  String get rateLabel =>
      '${amount2(interestRate)} / $interestUnit per ${amount2(interestRefAmount)}';

  factory Loan.fromJson(Map<String, dynamic> j) => Loan(
        id: j['id'] as String,
        kind: j['kind'] as String,
        party: (j['party'] as String?) ?? '',
        date: DateTime.parse(j['date'] as String),
        principal: (j['principal'] as num).toDouble(),
        interestRate: (j['interestRate'] as num).toDouble(),
        interestRefAmount: (j['interestRefAmount'] as num).toDouble(),
        interestUnit: j['interestUnit'] as String,
        countStartDay: (j['countStartDay'] as bool?) ?? false,
        note: (j['note'] as String?) ?? '',
        status: (j['status'] as String?) ?? 'open',
        daysElapsed: (j['daysElapsed'] as num?)?.toInt() ?? 0,
        accruedInterest: (j['accruedInterest'] as num?)?.toDouble() ?? 0,
        outstanding: (j['outstanding'] as num?)?.toDouble() ?? 0,
        repayment: j['repayment'] == null
            ? null
            : LoanRepayment.fromJson(j['repayment'] as Map<String, dynamic>),
      );
}
