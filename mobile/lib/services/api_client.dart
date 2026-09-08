import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isStockConflict => statusCode == 422;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;

  /// Bearer token for authenticated calls; null when signed out.
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(queryParameters: query);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  dynamic _handle(http.Response res) {
    final dynamic body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = (body is Map && body['error'] is String)
        ? body['error'] as String
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, message);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _http.post(
      _uri('/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    );
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStock() async {
    final res = await _http.get(_uri('/api/stock'), headers: _headers);
    return _handle(res) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions({String? type}) async {
    final res = await _http.get(
      _uri('/api/transactions', type == null ? null : {'type': type}),
      headers: _headers,
    );
    return _handle(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(
      Map<String, dynamic> payload) async {
    final res = await _http.post(
      _uri('/api/transactions'),
      headers: _headers,
      body: jsonEncode(payload),
    );
    return _handle(res) as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(String id) async {
    final res =
        await _http.delete(_uri('/api/transactions/$id'), headers: _headers);
    _handle(res);
  }
}
