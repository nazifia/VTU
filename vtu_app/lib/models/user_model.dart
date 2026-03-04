class UserModel {
  final String id;
  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final double balance;
  final String? profileImage;
  final bool isBiometricEnabled;
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
    this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  String get formattedBalance {
    return '₦${balance.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        )}';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      phone: json['phone'] ?? '',
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      balance: json['balance'] == null
          ? 0.0
          : json['balance'] is String
              ? double.tryParse(json['balance']) ?? 0.0
              : (json['balance'] as num).toDouble(),
      profileImage: json['profile_image'],
      isBiometricEnabled: json['is_biometric_enabled'] ?? false,
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
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

