import 'transaction.dart';

/// One party's unpaid balance, aggregated across their transactions.
/// Grouping is case-insensitive; [party] is the first spelling seen.
class OutstandingParty {
  OutstandingParty(this.party);

  String party;
  double totalDue = 0;
  final List<GoldTransaction> transactions = [];

  int get count => transactions.length;
}

class OutstandingReport {
  OutstandingReport(this.receivables, this.payables);

  /// Buyers who owe us, most owed first.
  final List<OutstandingParty> receivables;

  /// Sellers we owe, most owed first.
  final List<OutstandingParty> payables;

  double get totalReceivable => receivables.fold(0, (s, p) => s + p.totalDue);
  double get totalPayable => payables.fold(0, (s, p) => s + p.totalDue);

  /// Group the unpaid part of every transaction by party (case-insensitive).
  factory OutstandingReport.fromTransactions(List<GoldTransaction> txns) {
    final rec = <String, OutstandingParty>{};
    final pay = <String, OutstandingParty>{};

    for (final t in txns) {
      if (t.amountDue <= 0.005) continue;
      final raw = t.party.trim();
      final key = raw.isEmpty ? 'unnamed' : raw.toLowerCase();
      final display = raw.isEmpty ? 'Unnamed' : raw;
      final bucket = t.isSale ? rec : pay;
      final entry = bucket.putIfAbsent(key, () => OutstandingParty(display));
      // Prefer a capitalised spelling over an all-lowercase one.
      if (raw.isNotEmpty &&
          raw != raw.toLowerCase() &&
          entry.party == entry.party.toLowerCase()) {
        entry.party = raw;
      }
      entry.totalDue += t.amountDue;
      entry.transactions.add(t);
    }

    int byDueDesc(OutstandingParty a, OutstandingParty b) =>
        b.totalDue.compareTo(a.totalDue);

    return OutstandingReport(
      rec.values.toList()..sort(byDueDesc),
      pay.values.toList()..sort(byDueDesc),
    );
  }
}
