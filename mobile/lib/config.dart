class AppConfig {
  /// Base URL of the Node backend.
  ///
  /// Override per run:
  ///   flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000
  ///
  /// 10.0.2.2 is the Android emulator's alias for the host machine's localhost.
  /// For an iOS simulator use http://localhost:3000; for a physical device use
  /// the host's LAN IP.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000',
  );
}
