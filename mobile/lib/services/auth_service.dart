import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  AuthService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const String _key = 'gold_manager_token';

  Future<String?> readToken() => _storage.read(key: _key);
  Future<void> saveToken(String token) =>
      _storage.write(key: _key, value: token);
  Future<void> clear() => _storage.delete(key: _key);
}
