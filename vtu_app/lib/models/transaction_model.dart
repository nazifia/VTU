import '../utils/currency_formatter.dart';

// Transaction type is derived from the backend `category` field,
// while credit/debit direction comes from the backend `type` field.
enum TransactionType { transfer, airtime, data, deposit, electricity, cableTv, water, other }

enum TransactionStatus { pending, success, failed }

class TransactionModel {
  final String id;
  final TransactionType type;
  final TransactionStatus status;
  final double amount;
  final String description;
  final String? recipient;
  final String? provider;
  final DateTime createdAt;
  final String? reference;
  /// True if this is an incoming/credit transaction (e.g. wallet funding).
  final bool isCredit;
  final String? source;
  final String? destination;
  final String? accountName;

  TransactionModel({
    required this.id,
    required this.type,
    required this.status,
    required this.amount,
    required this.description,
    this.recipient,
    this.provider,
    required this.createdAt,
    this.reference,
    this.isCredit = false,
    this.source,
    this.destination,
    this.accountName,
  });

  String get formattedAmount {
    final prefix = isCredit ? '+' : '-';
    return '$prefix${amount.formatCurrency}';
  }

  String get typeLabel {
    switch (type) {
      case TransactionType.transfer:
        return 'Transfer';
      case TransactionType.airtime:
        return 'Airtime';
      case TransactionType.data:
        return 'Data';
      case TransactionType.deposit:
        return 'Deposit';
      case TransactionType.electricity:
        return 'Electricity';
      case TransactionType.cableTv:
        return 'Cable TV';
      case TransactionType.water:
        return 'Water';
      case TransactionType.other:
        return 'Other';
    }
  }

  String get statusLabel {
    switch (status) {
      case TransactionStatus.pending:
        return 'Pending';
      case TransactionStatus.success:
        return 'Success';
      case TransactionStatus.failed:
        return 'Failed';
    }
  }

  /// Map backend `category` string → [TransactionType] enum.
  static TransactionType _categoryToType(String? category) {
    switch (category) {
      case 'airtime':
        return TransactionType.airtime;
      case 'data':
        return TransactionType.data;
      case 'bank_transfer':
        return TransactionType.transfer;
      case 'wallet_funding':
        return TransactionType.deposit;
      case 'electricity':
        return TransactionType.electricity;
      case 'cable_tv':
        return TransactionType.cableTv;
      case 'water':
        return TransactionType.water;
      default:
        return TransactionType.other;
    }
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // `type` from backend is "credit" or "debit"
    final backendType = json['type'] as String? ?? '';
    // `category` from backend is "airtime", "data", "bank_transfer", "wallet_funding", etc.
    final category = json['category'] as String?;

    return TransactionModel(
      id: json['id']?.toString() ?? '',
      type: _categoryToType(category),
      isCredit: backendType == 'credit',
      status: TransactionStatus.values.firstWhere(
        (e) => e.name.toLowerCase() == (json['status'] as String?)?.toLowerCase(),
        orElse: () => TransactionStatus.pending,
      ),
      amount: (json['amount'] ?? 0) is String
          ? double.tryParse(json['amount']) ?? 0.0
          : (json['amount'] ?? 0).toDouble(),
      description: json['description'] ?? '',
      recipient: json['recipient'],
      provider: json['provider'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      reference: json['reference'],
      source: json['source'] ?? json['metadata']?['source'] ?? json['wallet']?['name'],
      destination: json['destination'] ?? json['metadata']?['destination'] ?? json['recipient_name'] ?? json['wallet_name'] ?? json['user_name'] ?? json['name'],
      accountName: json['account_name'] ?? json['metadata']?['account_name'] ?? json['recipient_name'] ?? json['wallet_name'] ?? json['beneficiary_name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': isCredit ? 'credit' : 'debit',
      'category': type.name,
      'status': status.name,
      'amount': amount,
      'description': description,
      'recipient': recipient,
      'provider': provider,
      'created_at': createdAt.toIso8601String(),
      'reference': reference,
      'source': source,
      'destination': destination,
      'account_name': accountName,
    };
  }
}

