import 'dart:async';
import 'package:dio/dio.dart';
import '../config/app_config.dart';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import 'storage_service.dart';

class _CacheEntry {
  final dynamic data;
  final DateTime expiresAt;
  _CacheEntry(this.data, this.expiresAt);
  bool get isValid => DateTime.now().isBefore(expiresAt);
}

class ApiService {
  late final Dio _dio;
  final StorageService _storage;
  final Map<String, _CacheEntry> _cache = {};

  // Per-endpoint cache durations
  static const _profileTtl        = Duration(minutes: 5);
  static const _transactionsTtl   = Duration(seconds: 30);
  static const _virtualAccountTtl = Duration(minutes: 10);
  static const _dataPlansTtl      = Duration(minutes: 30);
  static const _defaultTtl        = Duration(seconds: 30);

  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {'Content-Type': 'application/json'},
    ));
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Do not send tokens for auth endpoints (login, register, otp)
          if (!options.path.startsWith('/auth/')) {
            final token = await _storage.getAccessToken();
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401 && !error.requestOptions.path.startsWith('/auth/')) {
            try {
              await _refreshToken();
              final token = await _storage.getAccessToken();
              error.requestOptions.headers['Authorization'] = 'Bearer $token';
              final response = await _dio.fetch(error.requestOptions);
              handler.resolve(response);
              return;
            } catch (_) {}
          }
          handler.next(error);
        },
      ),
    );
  }

  Future<void> _refreshToken() async {
    final refreshToken = await _storage.getRefreshToken();
    if (refreshToken == null) throw Exception('No refresh token');
    final response = await _dio.post(
      '/auth/token/refresh/',
      data: {'refresh': refreshToken},
    );
    await _storage.saveTokens(
      accessToken: response.data['access'],
      refreshToken: response.data['refresh'] ?? refreshToken,
    );
  }

  // ── Cached GET ───────────────────────────────────────────────────────────
  Future<dynamic> _cachedGet(
    String path, {
    Map<String, dynamic>? queryParameters,
    Duration ttl = _defaultTtl,
  }) async {
    final cacheKey = '$path${queryParameters?.toString() ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isValid) return cached.data;

    final response = await _dio.get(path, queryParameters: queryParameters);
    _cache[cacheKey] = _CacheEntry(
      response.data,
      DateTime.now().add(ttl),
    );
    return response.data;
  }

  /// Clear all cache entries (e.g. on logout).
  void clearCache() => _cache.clear();

  /// Clear only entries whose cache key starts with [prefix].
  /// Use this for targeted invalidation after mutations so other cached
  /// data (data plans, virtual accounts, etc.) is not thrown away.
  void clearCacheFor(String prefix) =>
      _cache.removeWhere((key, _) => key.startsWith(prefix));

  // ── Auth endpoints ───────────────────────────────────────────────────────
  Future<Map<String, dynamic>> login({
    required String phone,
    required String pin,
  }) async {
    final response = await _dio.post(
      '/auth/login/',
      data: {'phone': phone, 'pin': pin},
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> register({
    required String phone,
    required String pin,
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    final response = await _dio.post(
      '/auth/register/',
      data: {
        'phone': phone,
        'pin': pin,
        'first_name': firstName,
        'last_name': lastName,
        'email': ?email,
      },
    );
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> sendOtp(String phone) async {
    final response =
        await _dio.post('/auth/send-otp/', data: {'phone': phone});
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    final response = await _dio.post(
      '/auth/verify-otp/',
      data: {'phone': phone, 'otp': otp},
    );
    return response.data as Map<String, dynamic>;
  }

  // ── User endpoints ───────────────────────────────────────────────────────
  Future<UserModel> getProfile() async {
    final data = await _cachedGet('/user/profile/', ttl: _profileTtl);
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/user/profile/', data: data);
    clearCacheFor('/user/profile/'); // only bust profile, not everything
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  /// Submit BVN and/or NIN for KYC verification.
  Future<Map<String, dynamic>> submitKyc({String? bvn, String? nin}) async {
    final data = <String, dynamic>{};
    if (bvn != null) data['bvn'] = bvn;
    if (nin != null) data['nin'] = nin;
    final response = await _dio.post('/user/kyc/', data: data);
    clearCacheFor('/user/profile/');
    return response.data as Map<String, dynamic>;
  }

  /// Set or change the transaction PIN.
  /// First-time: pass only [newPin] + [confirmPin].
  /// Changing: pass [currentPin] + [newPin] + [confirmPin].
  Future<void> setTransactionPin({
    String? currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    final data = <String, dynamic>{
      'new_pin': newPin,
      'confirm_pin': confirmPin,
    };
    if (currentPin != null) data['current_pin'] = currentPin;
    await _dio.post('/user/set-transaction-pin/', data: data);
  }

  // ── Transaction endpoints ────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactions({int page = 1}) async {
    final data = await _cachedGet(
      '/transactions/',
      queryParameters: {'page': page},
      ttl: _transactionsTtl,
    );
    final list = (data is Map && data['results'] != null)
        ? data['results'] as List
        : data is List
            ? data
            : [];
    return list
        .map((json) => TransactionModel.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ── VTU endpoints ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> purchaseAirtime({
    required String phone,
    required String provider,
    required double amount,
  }) async {
    final response = await _dio.post('/vtu/airtime/', data: {
      'phone': phone,
      'provider': provider,
      'amount': amount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> purchaseData({
    required String phone,
    required String provider,
    required String planId,
    required double amount,
  }) async {
    final response = await _dio.post('/vtu/data/', data: {
      'phone': phone,
      'provider': provider,
      'plan_id': planId,
      'amount': amount,
    });
    return response.data as Map<String, dynamic>;
  }

  Future<List<Map<String, dynamic>>> getDataPlans({String? provider}) async {
    final queryParams = provider != null ? {'provider': provider} : null;
    final data = await _cachedGet(
      '/vtu/data/plans/',
      queryParameters: queryParams,
      ttl: _dataPlansTtl,
    );
    return ((data as Map<String, dynamic>)['plans'] as List)
        .cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> payBill({
    required String billType,
    required String provider,
    required String accountNumber,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    final response = await _dio.post('/vtu/bills/', data: {
      'bill_type': billType,
      'provider': provider,
      'account_number': accountNumber,
      'amount': amount,
      'metadata': ?metadata,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Transfer endpoints ───────────────────────────────────────────────────
  Future<Map<String, dynamic>> bankTransfer({
    required String accountNumber,
    required String bankCode,
    required double amount,
    String? narration,
  }) async {
    final response = await _dio.post('/transfer/bank/', data: {
      'account_number': accountNumber,
      'bank_code': bankCode,
      'amount': amount,
      'narration': ?narration,
    });
    return response.data as Map<String, dynamic>;
  }

  /// Resolve account holder name from a bank account number + bank code.
  /// Calls the Django backend which in turn calls the Paystack API.
  Future<Map<String, dynamic>> verifyAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    final response = await _dio.get('/transfer/verify/', queryParameters: {
      'account_number': accountNumber,
      'bank_code': bankCode,
    });
    return response.data as Map<String, dynamic>;
  }

  // ── Wallet limits ────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> getWalletLimits() async {
    final data = await _cachedGet('/wallet/limits/', ttl: _profileTtl);
    return data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> updateWalletLimits({
    double? dailyLimit,
    double? monthlyLimit,
  }) async {
    final body = <String, dynamic>{};
    if (dailyLimit != null) body['daily_limit'] = dailyLimit;
    if (monthlyLimit != null) body['monthly_limit'] = monthlyLimit;
    final response = await _dio.patch('/wallet/limits/', data: body);
    clearCacheFor('/wallet/limits/');
    return response.data as Map<String, dynamic>;
  }

  // ── Wallet endpoints ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fundWallet({required double amount}) async {
    final ref = 'FUND-${DateTime.now().millisecondsSinceEpoch}';
    final response = await _dio.post('/wallet/fund/', data: {
      'amount': amount,
      'reference': ref,
    });
    // Only bust balance-sensitive caches, not virtual accounts / data plans
    clearCacheFor('/user/profile/');
    clearCacheFor('/transactions/');
    return response.data as Map<String, dynamic>;
  }

  /// Fetches the list of virtual bank accounts users can transfer money to
  /// in order to top up their wallet.
  Future<List<Map<String, dynamic>>> getVirtualAccounts() async {
    final data = await _cachedGet(
      '/wallet/virtual-accounts/',
      ttl: _virtualAccountTtl,
    );
    final list = data is List ? data : (data['accounts'] as List? ?? []);
    return list.cast<Map<String, dynamic>>();
  }

  /// Initiates a card payment. The backend creates a Paystack charge session
  /// and returns an authorization URL for WebView display.
  Future<Map<String, dynamic>> initiateCardPayment({
    required double amount,
  }) async {
    final response = await _dio.post('/payment/card/initiate/', data: {
      'amount': amount,
    });
    return response.data as Map<String, dynamic>;
  }
}
