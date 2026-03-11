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
    _isBiometricEnabled = await _storage.isBiometricEnabled();
    final storedPhone   = await _storage.getStoredPhone();

    // When biometric login is enabled and an account exists, always show the
    // login screen so the user authenticates each session with biometric or PIN.
    // This is the standard fintech UX (OPay, GTB, etc.).
    if (_isBiometricEnabled && storedPhone != null) {
      _state = AuthState.unauthenticated;
      notifyListeners();
      return;
    }

    // No biometric requirement — auto-restore from stored token if available.
    final token = await _storage.getAccessToken();
    if (token != null) {
      try {
        _user = await _api.getProfile();
        _state = AuthState.authenticated;
        notifyListeners();
        loadTransactions();
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
      // Persist phone so biometric login can re-authenticate without PIN
      await _storage.setStoredPhone(phone);
      if (result['user'] != null) {
        _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
      } else {
        _user = await _api.getProfile();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      loadTransactions(); // background — home screen shows immediately
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
    // Step 1 — native biometric prompt
    final authenticated = await _biometric.authenticate(
      reason: 'Authenticate to access Npay',
    );
    if (!authenticated) return false;

    // Step 2 — check what we have stored
    final token       = await _storage.getAccessToken();
    final storedPhone = await _storage.getStoredPhone();

    if (token == null && storedPhone == null) {
      _errorMessage = 'No saved account. Please log in with your PIN first.';
      notifyListeners();
      return false;
    }

    _state = AuthState.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      if (token != null) {
        // Happy path — valid session token still exists
        _user = await _api.getProfile();
      } else {
        // Token was cleared (after logout / session expiry).
        // Use the stored phone to issue a fresh login.
        // MockApiService accepts any PIN; a real backend would need a
        // biometric-backed credential endpoint instead.
        final result = await _api.login(
          phone: storedPhone!,
          pin: 'biometric-auth', // MockApiService accepts any PIN
        );
        await _storage.saveTokens(
          accessToken:  result['access']  as String,
          refreshToken: result['refresh'] as String,
        );
        _user = result['user'] != null
            ? UserModel.fromJson(result['user'] as Map<String, dynamic>)
            : await _api.getProfile();
      }

      _state = AuthState.authenticated;
      notifyListeners();
      loadTransactions();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      await _storage.clearTokens();
      _state = AuthState.unauthenticated;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      await _storage.clearTokens();
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
      await _storage.setStoredPhone(phone);
      if (result['user'] != null) {
        _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
      } else {
        _user = await _api.getProfile();
      }
      _state = AuthState.authenticated;
      notifyListeners();
      loadTransactions(); // background
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      _state = AuthState.error;
      notifyListeners();
      return false;
    }
  }

  /// Fetches fresh transactions from the server.
  /// Cache clearing is handled by the caller before this is invoked after
  /// mutations; for background refreshes the 30-second TTL handles staleness.
  Future<void> loadTransactions() async {
    try {
      _transactions = await _api.getTransactions();
      notifyListeners();
    } catch (_) {}
  }

  /// Refreshes the user profile (and wallet balance) from the server.
  Future<void> refreshProfile() async {
    try {
      _user = await _api.getProfile();
      notifyListeners();
    } catch (_) {}
  }

  /// Called after every mutation (purchase, transfer, fund).
  /// Clears only the stale caches then reloads profile + transactions in
  /// parallel — cuts post-transaction wait roughly in half.
  Future<void> _postMutationRefresh() async {
    _api.clearCacheFor('/user/profile/');
    _api.clearCacheFor('/transactions/');
    await Future.wait([refreshProfile(), loadTransactions()]);
  }

  Future<bool> purchaseAirtime({
    required String phone,
    required String provider,
    required double amount,
  }) async {
    try {
      await _api.purchaseAirtime(phone: phone, provider: provider, amount: amount);
      await _postMutationRefresh();
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
        phone: phone, provider: provider, planId: planId, amount: amount,
      );
      await _postMutationRefresh();
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
        accountNumber: accountNumber, bankCode: bankCode,
        amount: amount, narration: narration,
      );
      await _postMutationRefresh();
      return true;
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> payBill({
    required String billType,
    required String provider,
    required String accountNumber,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _api.payBill(
        billType: billType, provider: provider,
        accountNumber: accountNumber, amount: amount, metadata: metadata,
      );
      await _postMutationRefresh();
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

      // Cache for profile + transactions already cleared by api.fundWallet.
      // Fetch both in parallel.
      await Future.wait([loadTransactions(), refreshProfile()]);
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

  /// Submit BVN and/or NIN. Returns null on success, error string on failure.
  Future<String?> submitKyc({String? bvn, String? nin}) async {
    try {
      final result = await _api.submitKyc(bvn: bvn, nin: nin);
      if (result['user'] != null) {
        _user = UserModel.fromJson(result['user'] as Map<String, dynamic>);
        notifyListeners();
      }
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    } catch (e) {
      return e.toString();
    }
  }

  /// Set or change the transaction PIN.
  /// Returns null on success, or an error message string on failure.
  Future<String?> setTransactionPin({
    String? currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    try {
      await _api.setTransactionPin(
        currentPin: currentPin,
        newPin: newPin,
        confirmPin: confirmPin,
      );
      // Update local user so UI reflects pin is now set
      if (_user != null) {
        _user = _user!.copyWith(hasTransactionPin: true);
        notifyListeners();
      }
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    } catch (e) {
      return e.toString();
    }
  }

  /// Update the user's wallet spending limits.
  /// Returns null on success, or an error message string on failure.
  Future<String?> updateWalletLimits({
    double? dailyLimit,
    double? monthlyLimit,
  }) async {
    try {
      final result = await _api.updateWalletLimits(
        dailyLimit: dailyLimit,
        monthlyLimit: monthlyLimit,
      );
      if (_user != null) {
        _user = _user!.copyWith(
          dailyLimit: result['daily_limit'] is String
              ? double.tryParse(result['daily_limit']) ?? _user!.dailyLimit
              : (result['daily_limit'] as num?)?.toDouble() ?? _user!.dailyLimit,
          monthlyLimit: result['monthly_limit'] is String
              ? double.tryParse(result['monthly_limit']) ?? _user!.monthlyLimit
              : (result['monthly_limit'] as num?)?.toDouble() ?? _user!.monthlyLimit,
        );
        notifyListeners();
      }
      return null;
    } on DioException catch (e) {
      return _parseError(e);
    } catch (e) {
      return e.toString();
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

  /// Returns the current backend URL in use.
  String get serverUrl => _api.baseUrl;

  /// Updates the backend URL both in memory and persistent storage.
  /// Call this when the user changes the Server URL in Settings.
  Future<void> updateServerUrl(String url) async {
    await _storage.setServerUrl(url);
    _api.updateBaseUrl(url);
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
        'first_name': ?firstName,
        'last_name': ?lastName,
        'email': ?email,
      });
      _user = updated;
      notifyListeners();
    } on DioException catch (e) {
      _errorMessage = _parseError(e);
      notifyListeners();
    }
  }

  Future<void> logout() async {
    // Only clear tokens — keep stored phone and biometric preference so the
    // biometric button remains available on the next login screen.
    await _storage.clearTokens();
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
