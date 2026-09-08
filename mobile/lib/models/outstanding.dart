import 'transaction.dart';

/// One party's unpaid balance, aggregated across their transactions.
class OutstandingParty {
  OutstandingParty(this.party);

  final String party;
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

  /// Group the unpaid part of every transaction by party.
  factory OutstandingReport.fromTransactions(List<GoldTransaction> txns) {
    final rec = <String, OutstandingParty>{};
    final pay = <String, OutstandingParty>{};

    for (final t in txns) {
      if (t.amountDue <= 0.005) continue;
      final key = t.party.trim().isEmpty ? 'Unnamed' : t.party.trim();
      final bucket = t.isSale ? rec : pay;
      final entry = bucket.putIfAbsent(key, () => OutstandingParty(key));
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
