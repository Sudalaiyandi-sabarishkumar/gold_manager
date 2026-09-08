class AppSettings {
  const AppSettings({
    required this.openingCash,
    required this.openingGoldGrams,
  });

  final double openingCash;
  final double openingGoldGrams;

  static const AppSettings empty =
      AppSettings(openingCash: 0, openingGoldGrams: 0);

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        openingCash: (j['openingCash'] as num?)?.toDouble() ?? 0,
        openingGoldGrams: (j['openingGoldGrams'] as num?)?.toDouble() ?? 0,
      );
}
