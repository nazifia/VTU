import 'dart:math';
import '../models/user_model.dart';
import '../models/transaction_model.dart';
import 'api_service.dart';
import 'storage_service.dart';

/// Offline demo implementation of [ApiService].
///
/// All methods return realistic fake data and maintain in-memory state —
/// balance changes when you buy airtime or fund the wallet, transactions
/// accumulate, etc. No network connection required.
class MockApiService extends ApiService {
  MockApiService(StorageService storage) : super(storage);

  // ── In-memory state ────────────────────────────────────────────────────────

  // User state — mutated by updateProfile, submitKyc, setTransactionPin, etc.
  String _phone = '';
  String _firstName = 'Demo';
  String _lastName = 'User';
  String _email = 'demo@npay.app';
  double _balance = 50000.00;
  double _dailyLimit = 50000.0;
  double _monthlyLimit = 500000.0;
  bool _hasTransactionPin = false;
  bool _bvnLinked = false;
  bool _bvnVerified = false;
  bool _ninLinked = false;
  bool _ninVerified = false;

  // Transactions — prepopulated with realistic history
  final List<TransactionModel> _transactions = [
    TransactionModel(
      id: 'txn-001',
      type: TransactionType.deposit,
      status: TransactionStatus.success,
      amount: 20000,
      description: 'Wallet funding via bank transfer',
      isCredit: true,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
      reference: 'FUND-1001',
    ),
    TransactionModel(
      id: 'txn-002',
      type: TransactionType.airtime,
      status: TransactionStatus.success,
      amount: 1000,
      description: 'MTN Airtime — 08012345678',
      provider: 'MTN',
      recipient: '08012345678',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 1, hours: 5)),
      reference: 'AIR-1002',
    ),
    TransactionModel(
      id: 'txn-003',
      type: TransactionType.data,
      status: TransactionStatus.success,
      amount: 500,
      description: 'Airtel 1GB Data — 08098765432',
      provider: 'Airtel',
      recipient: '08098765432',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      reference: 'DAT-1003',
    ),
    TransactionModel(
      id: 'txn-004',
      type: TransactionType.transfer,
      status: TransactionStatus.success,
      amount: 5000,
      description: 'Transfer to John Doe',
      accountName: 'John Doe',
      destination: '0123456789',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      reference: 'TRF-1004',
    ),
    TransactionModel(
      id: 'txn-005',
      type: TransactionType.electricity,
      status: TransactionStatus.success,
      amount: 3000,
      description: 'EKEDC Electricity — 1234567890',
      provider: 'EKEDC',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      reference: 'BIL-1005',
    ),
    TransactionModel(
      id: 'txn-006',
      type: TransactionType.deposit,
      status: TransactionStatus.success,
      amount: 40000,
      description: 'Wallet funding via card payment',
      isCredit: true,
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
      reference: 'FUND-1006',
    ),
    TransactionModel(
      id: 'txn-007',
      type: TransactionType.cableTv,
      status: TransactionStatus.success,
      amount: 2500,
      description: 'DSTV Compact — 1234567890',
      provider: 'DSTV',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
      reference: 'BIL-1007',
    ),
    TransactionModel(
      id: 'txn-008',
      type: TransactionType.airtime,
      status: TransactionStatus.success,
      amount: 500,
      description: 'Glo Airtime — 09087654321',
      provider: 'Glo',
      recipient: '09087654321',
      isCredit: false,
      createdAt: DateTime.now().subtract(const Duration(days: 12)),
      reference: 'AIR-1008',
    ),
  ];

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Fake delay to make responses feel realistic.
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 600));

  String _ref(String prefix) =>
      '$prefix-${DateTime.now().millisecondsSinceEpoch}';

  Map<String, dynamic> _userJson() => {
        'id': 'mock-user-001',
        'phone': _phone,
        'first_name': _firstName,
        'last_name': _lastName,
        'email': _email,
        'balance': _balance.toStringAsFixed(2),
        'has_transaction_pin': _hasTransactionPin,
        'daily_limit': _dailyLimit.toStringAsFixed(2),
        'monthly_limit': _monthlyLimit.toStringAsFixed(2),
        'bvn_linked': _bvnLinked,
        'bvn_verified': _bvnVerified,
        'nin_linked': _ninLinked,
        'nin_verified': _ninVerified,
        'created_at': '2025-01-01T00:00:00Z',
      };

  Map<String, dynamic> _fakeTokens() => {
        'access': 'mock-access-token',
        'refresh': 'mock-refresh-token',
      };

  void _addTransaction(TransactionModel tx) => _transactions.insert(0, tx);

  // ── Auth ───────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> login({
    required String phone,
    required String pin,
  }) async {
    await _delay();
    if (pin.length < 4) {
      throw Exception('PIN must be at least 4 digits');
    }
    _phone = phone;
    return {
      ..._fakeTokens(),
      'user': _userJson(),
    };
  }

  @override
  Future<Map<String, dynamic>> register({
    required String phone,
    required String pin,
    required String firstName,
    required String lastName,
    String? email,
  }) async {
    await _delay();
    _phone = phone;
    _firstName = firstName;
    _lastName = lastName;
    _email = email ?? 'demo@npay.app';
    // Return fixed OTP so any entry works; the verify step accepts anything
    return {
      'message': 'Registration successful. Enter the OTP sent to $phone.',
      'otp': '123456',
    };
  }

  @override
  Future<Map<String, dynamic>> sendOtp(String phone) async {
    await _delay();
    return {'message': 'OTP sent to $phone', 'otp': '123456'};
  }

  @override
  Future<Map<String, dynamic>> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    await _delay();
    // Accept any 6-digit code (or the fixed "123456")
    if (otp.length < 4) throw Exception('Invalid OTP');
    _phone = phone;
    return {
      ..._fakeTokens(),
      'user': _userJson(),
    };
  }

  // ── User ───────────────────────────────────────────────────────────────────

  @override
  Future<UserModel> getProfile() async {
    await _delay();
    return UserModel.fromJson(_userJson());
  }

  @override
  Future<UserModel> updateProfile(Map<String, dynamic> data) async {
    await _delay();
    if (data['first_name'] != null) _firstName = data['first_name'] as String;
    if (data['last_name'] != null) _lastName = data['last_name'] as String;
    if (data['email'] != null) _email = data['email'] as String;
    return UserModel.fromJson(_userJson());
  }

  @override
  Future<Map<String, dynamic>> submitKyc({String? bvn, String? nin}) async {
    await _delay();
    if (bvn != null && bvn.isNotEmpty) {
      _bvnLinked = true;
      _bvnVerified = true;
    }
    if (nin != null && nin.isNotEmpty) {
      _ninLinked = true;
      _ninVerified = true;
    }
    return {'user': _userJson(), 'message': 'KYC submitted successfully'};
  }

  @override
  Future<void> setTransactionPin({
    String? currentPin,
    required String newPin,
    required String confirmPin,
  }) async {
    await _delay();
    if (newPin != confirmPin) throw Exception('PINs do not match');
    if (newPin.length < 4) throw Exception('PIN must be at least 4 digits');
    _hasTransactionPin = true;
  }

  // ── Transactions ───────────────────────────────────────────────────────────

  @override
  Future<List<TransactionModel>> getTransactions({int page = 1}) async {
    await _delay();
    return List.unmodifiable(_transactions);
  }

  // ── Wallet ─────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> fundWallet({required double amount}) async {
    await _delay();
    if (amount <= 0) throw Exception('Amount must be greater than 0');
    _balance += amount;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: TransactionType.deposit,
      status: TransactionStatus.success,
      amount: amount,
      description: 'Wallet funding',
      isCredit: true,
      createdAt: DateTime.now(),
      reference: _ref('FUND'),
    ));
    clearCacheFor('/user/profile/');
    clearCacheFor('/transactions/');
    return {
      'balance': _balance.toStringAsFixed(2),
      'message': 'Wallet funded successfully',
    };
  }

  @override
  Future<Map<String, dynamic>> getWalletLimits() async {
    await _delay();
    return {
      'daily_limit': _dailyLimit.toStringAsFixed(2),
      'monthly_limit': _monthlyLimit.toStringAsFixed(2),
    };
  }

  @override
  Future<Map<String, dynamic>> updateWalletLimits({
    double? dailyLimit,
    double? monthlyLimit,
  }) async {
    await _delay();
    if (dailyLimit != null) _dailyLimit = dailyLimit;
    if (monthlyLimit != null) _monthlyLimit = monthlyLimit;
    return {
      'daily_limit': _dailyLimit.toStringAsFixed(2),
      'monthly_limit': _monthlyLimit.toStringAsFixed(2),
    };
  }

  @override
  Future<List<Map<String, dynamic>>> getVirtualAccounts() async {
    await _delay();
    return [
      {
        'bank_name': 'Wema Bank',
        'account_number': '9876543210',
        'account_name': '$_firstName $_lastName',
      },
      {
        'bank_name': 'Providus Bank',
        'account_number': '5544332211',
        'account_name': '$_firstName $_lastName',
      },
    ];
  }

  @override
  Future<Map<String, dynamic>> initiateCardPayment({required double amount}) async {
    await _delay();
    // Simulate immediate success — credit balance directly
    _balance += amount;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: TransactionType.deposit,
      status: TransactionStatus.success,
      amount: amount,
      description: 'Card payment',
      isCredit: true,
      createdAt: DateTime.now(),
      reference: _ref('CARD'),
    ));
    return {
      'authorization_url': '',
      'reference': _ref('CARD'),
      'message': 'Payment successful',
    };
  }

  // ── VTU ────────────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> purchaseAirtime({
    required String phone,
    required String provider,
    required double amount,
  }) async {
    await _delay();
    _checkBalance(amount);
    _balance -= amount;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: TransactionType.airtime,
      status: TransactionStatus.success,
      amount: amount,
      description: '$provider Airtime — $phone',
      provider: provider,
      recipient: phone,
      isCredit: false,
      createdAt: DateTime.now(),
      reference: _ref('AIR'),
    ));
    return {'message': 'Airtime purchase successful', 'reference': _ref('AIR')};
  }

  @override
  Future<Map<String, dynamic>> purchaseData({
    required String phone,
    required String provider,
    required String planId,
    required double amount,
  }) async {
    await _delay();
    _checkBalance(amount);
    _balance -= amount;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: TransactionType.data,
      status: TransactionStatus.success,
      amount: amount,
      description: '$provider Data — $phone',
      provider: provider,
      recipient: phone,
      isCredit: false,
      createdAt: DateTime.now(),
      reference: _ref('DAT'),
    ));
    return {'message': 'Data purchase successful', 'reference': _ref('DAT')};
  }

  @override
  Future<List<Map<String, dynamic>>> getDataPlans({String? provider}) async {
    await _delay();
    final allPlans = <Map<String, dynamic>>[
      {'id': 'mtn-500mb', 'provider': 'MTN', 'size': '500MB', 'price': 150, 'validity': '30 days'},
      {'id': 'mtn-1gb',   'provider': 'MTN', 'size': '1GB',   'price': 300, 'validity': '30 days'},
      {'id': 'mtn-2gb',   'provider': 'MTN', 'size': '2GB',   'price': 500, 'validity': '30 days'},
      {'id': 'mtn-5gb',   'provider': 'MTN', 'size': '5GB',   'price': 1000,'validity': '30 days'},
      {'id': 'mtn-10gb',  'provider': 'MTN', 'size': '10GB',  'price': 2000,'validity': '30 days'},
      {'id': 'glo-500mb', 'provider': 'Glo', 'size': '500MB', 'price': 100, 'validity': '14 days'},
      {'id': 'glo-1gb',   'provider': 'Glo', 'size': '1GB',   'price': 250, 'validity': '30 days'},
      {'id': 'glo-2gb',   'provider': 'Glo', 'size': '2GB',   'price': 450, 'validity': '30 days'},
      {'id': 'glo-5gb',   'provider': 'Glo', 'size': '5GB',   'price': 900, 'validity': '30 days'},
      {'id': 'airt-500mb','provider': 'Airtel','size':'500MB','price': 150,'validity': '30 days'},
      {'id': 'airt-1gb',  'provider': 'Airtel','size':'1GB',  'price': 300,'validity': '30 days'},
      {'id': 'airt-2gb',  'provider': 'Airtel','size':'2GB',  'price': 500,'validity': '30 days'},
      {'id': 'airt-5gb',  'provider': 'Airtel','size':'5GB',  'price': 1000,'validity':'30 days'},
      {'id': '9mob-500mb','provider': '9mobile','size':'500MB','price':200,'validity': '30 days'},
      {'id': '9mob-1gb',  'provider': '9mobile','size':'1GB', 'price': 400,'validity': '30 days'},
      {'id': '9mob-2gb',  'provider': '9mobile','size':'2GB', 'price': 700,'validity': '30 days'},
    ];
    final filtered = provider == null
        ? allPlans
        : allPlans.where((p) => p['provider'] == provider).toList();
    return filtered;
  }

  @override
  Future<Map<String, dynamic>> payBill({
    required String billType,
    required String provider,
    required String accountNumber,
    required double amount,
    Map<String, dynamic>? metadata,
  }) async {
    await _delay();
    _checkBalance(amount);
    _balance -= amount;
    final label = {
      'electricity': 'Electricity',
      'cable_tv': 'Cable TV',
      'water': 'Water',
    }[billType] ?? 'Bill';
    final type = {
      'electricity': TransactionType.electricity,
      'cable_tv': TransactionType.cableTv,
      'water': TransactionType.water,
    }[billType] ?? TransactionType.other;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: type,
      status: TransactionStatus.success,
      amount: amount,
      description: '$provider $label — $accountNumber',
      provider: provider,
      isCredit: false,
      createdAt: DateTime.now(),
      reference: _ref('BIL'),
    ));
    return {'message': '$label payment successful', 'reference': _ref('BIL')};
  }

  // ── Transfer ───────────────────────────────────────────────────────────────

  @override
  Future<Map<String, dynamic>> bankTransfer({
    required String accountNumber,
    required String bankCode,
    required double amount,
    String? narration,
  }) async {
    await _delay();
    _checkBalance(amount);
    _balance -= amount;
    _addTransaction(TransactionModel(
      id: 'txn-${Random().nextInt(99999)}',
      type: TransactionType.transfer,
      status: TransactionStatus.success,
      amount: amount,
      description: narration ?? 'Bank Transfer — $accountNumber',
      destination: accountNumber,
      isCredit: false,
      createdAt: DateTime.now(),
      reference: _ref('TRF'),
    ));
    return {'message': 'Transfer successful', 'reference': _ref('TRF')};
  }

  @override
  Future<Map<String, dynamic>> verifyAccount({
    required String accountNumber,
    required String bankCode,
  }) async {
    await _delay();
    // Return a convincing fake account name based on last digits
    final lastTwo = accountNumber.length >= 2
        ? accountNumber.substring(accountNumber.length - 2)
        : '00';
    const names = [
      'ADEBAYO OLUWASEUN',
      'CHUKWU EMEKA JOSEPH',
      'IBRAHIM AISHA FATIMA',
      'OKONKWO CHIOMA RUTH',
      'BABATUNDE DAVID OLALEKAN',
      'NWOSU BLESSING CHIDINMA',
      'AFOLABI SAMUEL ADEWALE',
      'EZE CHINONSO VICTOR',
    ];
    final name = names[int.parse(lastTwo) % names.length];
    return {'account_name': name, 'account_number': accountNumber};
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  void _checkBalance(double amount) {
    if (amount > _balance) {
      throw Exception('Insufficient balance. Your balance is ₦${_balance.toStringAsFixed(2)}');
    }
  }

  // Cache methods are inherited (no-ops in mock since no network caching needed)
  @override
  String get baseUrl => 'mock://offline';

  @override
  void updateBaseUrl(String url) {} // no-op in mock mode
}
