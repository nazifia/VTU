import 'package:intl/intl.dart';

extension CurrencyFormatter on num {
  String get formatCurrency {
    final formatter = NumberFormat.currency(
      locale: 'en_NG',
      symbol: '₦',
      decimalDigits: this % 1 == 0 ? 0 : 2,
    );
    return formatter.format(this);
  }
}
