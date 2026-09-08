import 'package:intl/intl.dart';

final NumberFormat _inr0 =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final NumberFormat _inr2 =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final NumberFormat _grams = NumberFormat('#,##0.00', 'en_IN');
final DateFormat _date = DateFormat('dd MMM yyyy');

String inr(num n) => _inr0.format(n);
String inr2(num n) => _inr2.format(n);
String grams(num n) => '${_grams.format(n)} g';

/// "+₹1,200" / "−₹350" using a real minus sign.
String signedInr(num n) => (n >= 0 ? '+' : '−') + inr(n.abs());

String fmtDate(DateTime d) => _date.format(d.toLocal());
