import '../utils/currency_formatter.dart';

class UserModel {
  final String id;
  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final double balance;
  final String? profileImage;
  final bool isBiometricEnabled;
  final bool hasTransactionPin;
  final double dailyLimit;
  final double monthlyLimit;
  final bool bvnLinked;
  final bool bvnVerified;
  final bool ninLinked;
  final bool ninVerified;
  final DateTime? createdAt;

  UserModel({
    required this.id,
    required this.phone,
    required this.firstName,
    required this.lastName,
    this.email = '',
    this.balance = 0.0,
    this.profileImage,
    this.isBiometricEnabled = false,
    this.hasTransactionPin = false,
    this.dailyLimit = 50000,
    this.monthlyLimit = 500000,
    this.bvnLinked = false,
    this.bvnVerified = false,
    this.ninLinked = false,
    this.ninVerified = false,
    this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  String get formattedBalance {
    return balance.formatCurrency;
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    double parseDecimal(dynamic v, double fallback) {
      if (v == null) return fallback;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? fallback;
    }

    return UserModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      balance: parseDecimal(json['balance'], 0.0),
      profileImage: json['profile_image'],
      isBiometricEnabled: json['is_biometric_enabled'] ?? false,
      hasTransactionPin: json['has_transaction_pin'] ?? false,
      dailyLimit: parseDecimal(json['daily_limit'], 50000),
      monthlyLimit: parseDecimal(json['monthly_limit'], 500000),
      bvnLinked: json['bvn_linked'] ?? false,
      bvnVerified: json['bvn_verified'] ?? false,
      ninLinked: json['nin_linked'] ?? false,
      ninVerified: json['nin_verified'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'balance': balance,
      'profile_image': profileImage,
      'is_biometric_enabled': isBiometricEnabled,
      'has_transaction_pin': hasTransactionPin,
      'daily_limit': dailyLimit,
      'monthly_limit': monthlyLimit,
      'bvn_linked': bvnLinked,
      'bvn_verified': bvnVerified,
      'nin_linked': ninLinked,
      'nin_verified': ninVerified,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? id,
    String? phone,
    String? firstName,
    String? lastName,
    String? email,
    double? balance,
    String? profileImage,
    bool? isBiometricEnabled,
    bool? hasTransactionPin,
    double? dailyLimit,
    double? monthlyLimit,
    bool? bvnLinked,
    bool? bvnVerified,
    bool? ninLinked,
    bool? ninVerified,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      phone: phone ?? this.phone,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      balance: balance ?? this.balance,
      profileImage: profileImage ?? this.profileImage,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      hasTransactionPin: hasTransactionPin ?? this.hasTransactionPin,
      dailyLimit: dailyLimit ?? this.dailyLimit,
      monthlyLimit: monthlyLimit ?? this.monthlyLimit,
      bvnLinked: bvnLinked ?? this.bvnLinked,
      bvnVerified: bvnVerified ?? this.bvnVerified,
      ninLinked: ninLinked ?? this.ninLinked,
      ninVerified: ninVerified ?? this.ninVerified,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

