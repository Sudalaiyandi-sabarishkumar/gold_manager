import 'package:intl/intl.dart';

final NumberFormat _inr0 =
    NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final NumberFormat _grams = NumberFormat('#,##0.000', 'en_IN');
final DateFormat _date = DateFormat('dd MMM yyyy');

const _istOffset = Duration(hours: 5, minutes: 30);

/// Reads [wallClock]'s year/month/day/hour/... fields as an IST wall-clock
/// time (ignoring its isUtc flag and the device's own timezone) and returns
/// the absolute UTC instant that represents. Use this whenever a date/time
/// picked on-screen needs to be sent to the server, so the stored instant is
/// correct regardless of what timezone the device or server happen to be set
/// to.
DateTime istToUtc(DateTime wallClock) {
  return DateTime.utc(
    wallClock.year,
    wallClock.month,
    wallClock.day,
    wallClock.hour,
    wallClock.minute,
    wallClock.second,
    wallClock.millisecond,
  ).subtract(_istOffset);
}

/// The reverse of [istToUtc]: converts an absolute instant (as parsed from
/// the server, always UTC) into IST wall-clock fields for display, ignoring
/// the device's own timezone.
DateTime toIst(DateTime instant) => instant.toUtc().add(_istOffset);

String inr(num n) => _inr0.format(n);
String grams(num n) => '${_grams.format(n)} g';

/// "+₹1,200" / "−₹350" using a real minus sign.
String signedInr(num n) => (n >= 0 ? '+' : '−') + inr(n.abs());

String fmtDate(DateTime d) => _date.format(toIst(d));
