import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';

enum AuthState { initial, loading, authenticated, unauthenticated, error }

class AuthProvider with ChangeNotifier {
  final ApiService _api;
  final StorageService _storage;
  final BiometricService _biometric;

  AuthState _state = AuthState.initial;
  UserModel? _user;
  List<TransactionModel> _transactions = [];
  String? _errorMessage;
  bool _isBiometricEnabled = false;

  AuthProvider(this._api, this._storage, this._biometric);

  AuthState get state => _state;
  UserModel? get user => _user;
  List<TransactionModel> get transactions => _transactions;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _state == AuthState.authenticated;
  bool get isLoading => _state == AuthState.loading;
  bool get isBiometricEnabled => _isBiometricEnabled;
  ApiService get api => _api; // exposed so screens can call verifyAccount, getVirtualAccounts, etc.

  Future<void> init() async {
    final token = await _storage.getAccessToken();
    _isBiometricEnabled = await _storage.isBiometricEnabled();
    if (token != null) {
      try {
        _user = await _api.getProfile();
        _state = AuthState.authenticated;
        notifyListeners();
        await loadTransactions();
      } catch (_) {
        await _storage.clearTokens();
        _state = AuthState.unauthenticated;
        notifyListeners();
      }
    } else {
      _state = AuthState.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> login({required String phone, required String pin}) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.login(phone: phone, pin: pin);
      await _storage.saveTokens(
        accessToken: result['access'] as String,
        refreshToken: result['refresh'] as String,
      );
      if (result['user'] != null) {
        _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
      } else {
        _user = await _api.getProfile();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      await loadTransactions();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> loginWithBiometric() async {
    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate to access your VTU wallet',
    );
    if (!authenticated) return false;
    // Load existing session if token is still valid
    final token = await _storage.getAccessToken();
    if (token == null) return false;
    try {
      _state = AuthState.loading;
      notifyListeners();
      _user = await _api.getProfile();
      _state = AuthState.authenticated;
      notifyListeners();
      await loadTransactions();
      return true;
    } catch (_) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    }
  }

  /// Returns the OTP code string on success (for dev display), or null on failure.
  Future<String?> register({
    required String phone,
    required String pin,
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.register(
        phone: phone,
        pin: pin,
        firstName: firstName,
        lastName: lastName,
        email: email,
      );
      _state = AuthState.unauthenticated; // user still needs OTP verification
      notifyListeners();
      return result['otp'] as String?; // backend returns OTP in dev mode
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _state = AuthState.error;
      notifyListeners();
      return null;
    }
  }

  Future<bool> sendOtp(String phone) async {
    try {
      await _api.sendOtp(phone);
      return true;
    } catch (e) {
      _errorMessage = 'Failed to send OTP. Please try again.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOtp({required String phone, required String otp}) async {
    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await _api.verifyOtp(phone: phone, otp: otp);
      await _storage.saveTokens(
        accessToken: result['access'] as String,
        refreshToken: result['refresh'] as String,
      );
      if (result['user'] != null) {
        _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
      } else {
        _user = await _api.getProfile();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      await loadTransactions();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Fetches fresh transactions from the server.
  /// Always busts the API cache first so mutations are immediately reflected.
  Future<void> loadTransactions() async {
    try {
      _api.clearCache();
      _transactions = await _api.getTransactions();
      notifyListeners();
    } catch (_) {}
  }

  /// Refreshes the user profile (and wallet balance) from the server.
  Future<void> refreshProfile() async {
    try {
      _api.clearCache();
      _user = await _api.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  Future<bool> purchaseAirtime({
    required String phone,
    required String provider,
    required double amount,
  }) async {
    try {
      await _api.purchaseAirtime(
          phone: phone, provider: provider, amount: amount);
      // loadTransactions clears cache before fetching — balance + transactions both updated.
      await loadTransactions();
      await refreshProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> purchaseData({
    required String phone,
    required String provider,
    required String planId,
    required double amount,
  }) async {
    try {
      await _api.purchaseData(
        phone: phone,
        provider: provider,
        planId: planId,
        amount: amount,
      );
      await loadTransactions();
      await refreshProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> bankTransfer({
    required String accountNumber,
    required String bankCode,
    required double amount,
    String? narration,
  }) async {
    try {
      await _api.bankTransfer(
        accountNumber: accountNumber,
        bankCode: bankCode,
        amount: amount,
        narration: narration,
      );
      await loadTransactions();
      await refreshProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> fundWallet({required double amount}) async {
    _errorMessage = null;
    try {
      final result = await _api.fundWallet(amount: amount);

      // ── Instant balance update ────────────────────────────────────────────
      // The /wallet/fund/ endpoint returns {"balance": "...", "message": "..."}.
      // Apply the new balance immediately so the dashboard updates without
      // waiting for the full profile round-trip.
      final rawBalance = result['balance'];
      if (rawBalance != null && _user != null) {
        final newBalance = rawBalance is String
            ? double.tryParse(rawBalance) ?? _user!.balance
            : (rawBalance as num).toDouble();
        _user = _user!.copyWith(balance: newBalance);
        notifyListeners();
      }

      // Fetch fresh transactions (cache is already cleared by api.fundWallet).
      await loadTransactions();

      // Sync full profile to capture any server-side changes.
      await refreshProfile();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> setBiometricEnabled(bool value) async {
    _isBiometricEnabled = value;
    await _storage.setBiometricEnabled(value);
    if (_user != null) {
      _user = _user!.copyWith(isBiometricEnabled: value);
    }
    notifyListeners();
  }

  Future<void> updateProfile({
    String? firstName,
    String? lastName,
    String? email,
  }) async {
    if (_user == null) return;
    try {
      final updated = await _api.updateProfile({
        if (firstName != null) 'first_name': firstName,
        if (lastName != null) 'last_name': lastName,
        if (email != null) 'email': email,
      });
      _user = updated;
      notifyListeners();
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _storage.clearAll();
    _user = null;
    _transactions = [];
    _state = AuthState.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_state == AuthState.error) {
      _state = AuthState.unauthenticated;
    }
    notifyListeners();
  }

  String _parseError(DioException e) {
    if (e.response?.data is Map) {
      final data = e.response!.data as Map;
      if (data['detail'] != null) return data['detail'].toString();
      if (data['message'] != null) return data['message'].toString();
      if (data['non_field_errors'] != null) {
        return (data['non_field_errors'] as List).first.toString();
      }
      final firstKey = data.keys.first;
      final firstVal = data[firstKey];
      if (firstVal is List) return '$firstKey: ${firstVal.first}';
      return firstVal.toString();
    }
    if (e.type == DioExceptionType.connectionTimeout) {
      return 'Connection timeout. Check your internet.';
    }
    if (e.type == DioExceptionType.connectionError) {
      return 'No internet connection.';
    }
    return e.message ?? 'An unexpected error occurred.';
  }
}
