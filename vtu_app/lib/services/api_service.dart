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

  ApiService(this._storage) {
    _dio = Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
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
  Future<dynamic> _cachedGet(String path,
      {Map<String, dynamic>? queryParameters}) async {
    final cacheKey = '$path${queryParameters?.toString() ?? ''}';
    final cached = _cache[cacheKey];
    if (cached != null && cached.isValid) return cached.data;

    final response =
        await _dio.get(path, queryParameters: queryParameters);
    _cache[cacheKey] = _CacheEntry(
      response.data,
      DateTime.now().add(Duration(milliseconds: AppConfig.cacheTtlMs)),
    );
    return response.data;
  }

  void clearCache() => _cache.clear();

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
    final data = await _cachedGet('/user/profile/');
    return UserModel.fromJson(data as Map<String, dynamic>);
  }

  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    final response = await _dio.patch('/user/profile/', data: data);
    clearCache(); // profile changed — bust cache
    return UserModel.fromJson(response.data as Map<String, dynamic>);
  }

  // ── Transaction endpoints ────────────────────────────────────────────────
  Future<List<TransactionModel>> getTransactions({int page = 1}) async {
    final data = await _cachedGet('/transactions/', queryParameters: {
      'page': page,
    });
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
    final response = await _dio.get('/vtu/data/plans/', queryParameters: queryParams);
    final data = response.data as Map<String, dynamic>;
    return (data['plans'] as List).cast<Map<String, dynamic>>();
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

  // ── Wallet endpoints ─────────────────────────────────────────────────────
  Future<Map<String, dynamic>> fundWallet({required double amount}) async {
    final ref = 'FUND-${DateTime.now().millisecondsSinceEpoch}';
    final response = await _dio.post('/wallet/fund/', data: {
      'amount': amount,
      'reference': ref,
    });
    clearCache(); // balance changed
    return response.data as Map<String, dynamic>;
  }

  /// Fetches the list of virtual bank accounts users can transfer money to
  /// in order to top up their wallet.
  Future<List<Map<String, dynamic>>> getVirtualAccounts() async {
    final data = await _cachedGet('/wallet/virtual-accounts/');
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
