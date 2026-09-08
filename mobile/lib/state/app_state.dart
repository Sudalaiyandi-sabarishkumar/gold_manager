import 'package:flutter/foundation.dart';

import '../models/loan.dart';
import '../models/settings.dart';
import '../models/stock.dart';
import '../models/transaction.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, signedOut, signedIn }

/// Single app-wide store. Every mutating action calls the API and then
/// [refresh], so stock and the ledger are always re-pulled from the server
/// and never drift on the client.
class AppState extends ChangeNotifier {
  AppState({ApiClient? api, AuthService? auth})
      : _api = api ?? ApiClient(),
        _auth = auth ?? AuthService();

  final ApiClient _api;
  final AuthService _auth;

  AuthStatus status = AuthStatus.unknown;
  StockSummary stock = StockSummary.empty;
  List<GoldTransaction> transactions = const [];
  List<Loan> loans = const [];
  AppSettings settings = AppSettings.empty;
  bool loading = false;
  String? error;

  Future<void> bootstrap() async {
    final token = await _auth.readToken();
    if (token == null) {
      status = AuthStatus.signedOut;
      notifyListeners();
      return;
    }
    _api.token = token;
    status = AuthStatus.signedIn;
    notifyListeners();
    await refresh();
  }

  Future<void> login(String username, String password) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final res = await _api.login(username.trim(), password);
      final token = res['token'] as String;
      await _auth.saveToken(token);
      _api.token = token;
      status = AuthStatus.signedIn;
      loading = false;
      notifyListeners();
      await refresh();
    } on ApiException catch (e) {
      loading = false;
      error = e.isUnauthorized ? 'Wrong username or password' : e.message;
      notifyListeners();
      rethrow;
    } catch (_) {
      loading = false;
      error = 'Could not reach the server';
      notifyListeners();
      rethrow;
    }
  }

  Future<void> logout() async {
    await _auth.clear();
    _api.token = null;
    status = AuthStatus.signedOut;
    stock = StockSummary.empty;
    transactions = const [];
    loans = const [];
    settings = AppSettings.empty;
    error = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        _api.getStock(),
        _api.getTransactions(),
        _api.getLoans(),
        _api.getSettings(),
      ]);
      stock = StockSummary.fromJson(results[0] as Map<String, dynamic>);
      transactions = (results[1] as List<dynamic>)
          .map((e) => GoldTransaction.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      loans = (results[2] as List<dynamic>)
          .map((e) => Loan.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
      settings = AppSettings.fromJson(results[3] as Map<String, dynamic>);
      loading = false;
      notifyListeners();
    } on ApiException catch (e) {
      loading = false;
      if (e.isUnauthorized) {
        await logout();
        return;
      }
      error = e.message;
      notifyListeners();
    } catch (_) {
      loading = false;
      error = 'Could not reach the server';
      notifyListeners();
    }
  }

  /// Creates a transaction. Throws [ApiException] (e.g. 422 when a sale exceeds
  /// stock) for the caller to surface.
  Future<GoldTransaction> addTransaction({
    required String type,
    required DateTime date,
    required String party,
    required double weightGrams,
    required double ratePerGram,
    required String note,
    required double amountPaid,
  }) async {
    final res = await _api.createTransaction({
      'type': type,
      'date': date.toIso8601String(),
      'party': party,
      'weightGrams': weightGrams,
      'ratePerGram': ratePerGram,
      'note': note,
      'amountPaid': amountPaid,
    });
    final txn = GoldTransaction.fromJson(res);
    await refresh();
    return txn;
  }

  Future<void> deleteTransaction(String id) async {
    await _api.deleteTransaction(id);
    await refresh();
  }

  /// Records an instalment against a transaction. Throws [ApiException]
  /// (422 when the amount exceeds what is outstanding).
  Future<void> addPayment(
    String transactionId, {
    required double amount,
    DateTime? date,
    String note = '',
  }) async {
    await _api.addPayment(transactionId,
        amount: amount, date: date, note: note);
    await refresh();
  }

  Future<void> deletePayment(String transactionId, String paymentId) async {
    await _api.deletePayment(transactionId, paymentId);
    await refresh();
  }

  /// Records payments against several bills at once (person-level settlement).
  /// Each entry: { transactionId, amount, note? }.
  Future<void> settleParty(List<Map<String, dynamic>> allocations) async {
    await _api.settleParty(allocations);
    await refresh();
  }

  // ---- loans ----

  Future<Loan> createLoan(Map<String, dynamic> payload) async {
    final res = await _api.createLoan(payload);
    final loan = Loan.fromJson(res);
    await refresh();
    return loan;
  }

  Future<void> repayLoan(String id, Map<String, dynamic> body) async {
    await _api.repayLoan(id, body);
    await refresh();
  }

  Future<void> reopenLoan(String id) async {
    await _api.reopenLoan(id);
    await refresh();
  }

  Future<void> deleteLoan(String id) async {
    await _api.deleteLoan(id);
    await refresh();
  }

  Future<void> updateSettings(
      {double? openingCash, double? openingGoldGrams}) async {
    await _api.updateSettings({
      if (openingCash != null) 'openingCash': openingCash,
      if (openingGoldGrams != null) 'openingGoldGrams': openingGoldGrams,
    });
    await refresh();
  }

  /// Distinct party names already used across transactions and loans,
  /// case-insensitive, keeping the first spelling seen. Feeds the name dropdowns.
  List<String> get partyNames {
    final seen = <String, String>{};
    void add(String raw) {
      final v = raw.trim();
      if (v.isEmpty) return;
      seen.putIfAbsent(v.toLowerCase(), () => v);
    }

    for (final t in transactions) {
      add(t.party);
    }
    for (final l in loans) {
      add(l.party);
    }
    final names = seen.values.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  /// If [name] matches a known party case-insensitively, return that spelling.
  String canonicalParty(String name) {
    final raw = name.trim();
    if (raw.isEmpty) return '';
    for (final n in partyNames) {
      if (n.toLowerCase() == raw.toLowerCase()) return n;
    }
    return raw;
  }
}
