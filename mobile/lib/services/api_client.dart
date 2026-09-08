import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';

class ApiException implements Exception {
  ApiException(this.statusCode, this.message);
  final int statusCode; // 0 = never reached the server
  final String message;

  bool get isUnauthorized => statusCode == 401;
  bool get isStockConflict => statusCode == 422;
  bool get isNetworkError => statusCode == 0;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({http.Client? client}) : _http = client ?? http.Client();

  final http.Client _http;
  static const Duration _timeout = Duration(seconds: 8);

  /// Bearer token for authenticated calls; null when signed out.
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) =>
      Uri.parse('${AppConfig.apiBaseUrl}$path').replace(
        queryParameters: (query == null || query.isEmpty) ? null : query,
      );

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Applies a timeout and turns "server unreachable" into a clear message
  /// instead of an indefinite hang.
  Future<http.Response> _guard(Future<http.Response> request) async {
    try {
      return await request.timeout(_timeout);
    } on TimeoutException {
      throw ApiException(
        0,
        'The server took too long to respond. Check that the backend is running '
        'and API_BASE_URL points to it (currently ${AppConfig.apiBaseUrl}).',
      );
    } catch (_) {
      throw ApiException(
        0,
        'Cannot reach the server at ${AppConfig.apiBaseUrl}.',
      );
    }
  }

  dynamic _handle(http.Response res) {
    final dynamic body = res.body.isEmpty ? null : jsonDecode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return body;
    final message = (body is Map && body['error'] is String)
        ? body['error'] as String
        : 'Request failed (${res.statusCode})';
    throw ApiException(res.statusCode, message);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _guard(_http.post(
      _uri('/api/auth/login'),
      headers: _headers,
      body: jsonEncode({'username': username, 'password': password}),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getStock() async {
    final res = await _guard(_http.get(_uri('/api/stock'), headers: _headers));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<List<dynamic>> getTransactions({
    String? type,
    String? query,
    DateTime? from,
    DateTime? to,
  }) async {
    final params = <String, String>{
      if (type != null) 'type': type,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (from != null) 'from': _ymd(from),
      if (to != null) 'to': _ymd(to),
    };
    final res = await _guard(
        _http.get(_uri('/api/transactions', params), headers: _headers));
    return _handle(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createTransaction(
      Map<String, dynamic> payload) async {
    final res = await _guard(_http.post(
      _uri('/api/transactions'),
      headers: _headers,
      body: jsonEncode(payload),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<void> deleteTransaction(String id) async {
    final res = await _guard(
        _http.delete(_uri('/api/transactions/$id'), headers: _headers));
    _handle(res);
  }

  Future<Map<String, dynamic>> addPayment(
    String transactionId, {
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    final res = await _guard(_http.post(
      _uri('/api/transactions/$transactionId/payments'),
      headers: _headers,
      body: jsonEncode({
        'amount': amount,
        if (date != null) 'date': date.toIso8601String(),
        'note': note,
      }),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> deletePayment(
    String transactionId,
    String paymentId,
  ) async {
    final res = await _guard(_http.delete(
      _uri('/api/transactions/$transactionId/payments/$paymentId'),
      headers: _headers,
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> getOutstanding() async {
    final res =
        await _guard(_http.get(_uri('/api/outstanding'), headers: _headers));
    return _handle(res) as Map<String, dynamic>;
  }

  /// Records one payment per bill in a single call.
  /// allocations: [{ transactionId, amount, note? }]
  Future<void> settleParty(List<Map<String, dynamic>> allocations) async {
    final res = await _guard(_http.post(
      _uri('/api/parties/settle'),
      headers: _headers,
      body: jsonEncode({'allocations': allocations}),
    ));
    _handle(res);
  }

  // ---- loans ----

  Future<List<dynamic>> getLoans(
      {String? status, String? kind, String? query}) async {
    final params = <String, String>{
      if (status != null) 'status': status,
      if (kind != null) 'kind': kind,
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final res =
        await _guard(_http.get(_uri('/api/loans', params), headers: _headers));
    return _handle(res) as List<dynamic>;
  }

  Future<Map<String, dynamic>> createLoan(Map<String, dynamic> payload) async {
    final res = await _guard(_http.post(
      _uri('/api/loans'),
      headers: _headers,
      body: jsonEncode(payload),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> repayLoan(
      String id, Map<String, dynamic> body) async {
    final res = await _guard(_http.post(
      _uri('/api/loans/$id/repay'),
      headers: _headers,
      body: jsonEncode(body),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<void> reopenLoan(String id) async {
    final res = await _guard(
        _http.delete(_uri('/api/loans/$id/repay'), headers: _headers));
    _handle(res);
  }

  Future<void> deleteLoan(String id) async {
    final res =
        await _guard(_http.delete(_uri('/api/loans/$id'), headers: _headers));
    _handle(res);
  }

  // ---- settings ----

  Future<Map<String, dynamic>> getSettings() async {
    final res =
        await _guard(_http.get(_uri('/api/settings'), headers: _headers));
    return _handle(res) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateSettings(Map<String, dynamic> body) async {
    final res = await _guard(_http.put(
      _uri('/api/settings'),
      headers: _headers,
      body: jsonEncode(body),
    ));
    return _handle(res) as Map<String, dynamic>;
  }

  static String _ymd(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
