class AppSettings {
  const AppSettings({
    required this.openingCash,
    required this.openingGoldGrams,
    this.quickCheckSeedNetQtyGrams = 0,
    this.quickCheckSeedCarryRate = 0,
    this.quickCheckSeedSaleRate = 0,
    this.quickCheckSeedPurchasesTotal = 0,
    this.quickCheckSeedSalesTotal = 0,
  });

  final double openingCash;
  final double openingGoldGrams;

  // Carry-forward starting point for QuickCheckResult.compute() after a
  // "shrink" has folded older transactions away. All 0 until the first
  // shrink ever happens.
  final double quickCheckSeedNetQtyGrams;
  final double quickCheckSeedCarryRate;
  final double quickCheckSeedSaleRate;
  final double quickCheckSeedPurchasesTotal;
  final double quickCheckSeedSalesTotal;

  static const AppSettings empty =
      AppSettings(openingCash: 0, openingGoldGrams: 0);

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        openingCash: (j['openingCash'] as num?)?.toDouble() ?? 0,
        openingGoldGrams: (j['openingGoldGrams'] as num?)?.toDouble() ?? 0,
        quickCheckSeedNetQtyGrams:
            (j['quickCheckSeedNetQtyGrams'] as num?)?.toDouble() ?? 0,
        quickCheckSeedCarryRate:
            (j['quickCheckSeedCarryRate'] as num?)?.toDouble() ?? 0,
        quickCheckSeedSaleRate:
            (j['quickCheckSeedSaleRate'] as num?)?.toDouble() ?? 0,
        quickCheckSeedPurchasesTotal:
            (j['quickCheckSeedPurchasesTotal'] as num?)?.toDouble() ?? 0,
        quickCheckSeedSalesTotal:
            (j['quickCheckSeedSalesTotal'] as num?)?.toDouble() ?? 0,
      );
}
