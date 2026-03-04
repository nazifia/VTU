import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../config/theme.dart';
import '../config/banks.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ─────────────────────────────────────────────────────────────────────────────

const _kPresets = [500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0];

/// Amount preset chip row + custom text field, self-contained.
class _AmountPicker extends StatelessWidget {
  final double? selectedPreset;
  final TextEditingController customCtrl;
  final ValueChanged<double> onPreset;
  final VoidCallback onCustomChange;

  const _AmountPicker({
    required this.selectedPreset,
    required this.customCtrl,
    required this.onPreset,
    required this.onCustomChange,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amount to Add', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _kPresets.map((amt) {
            final sel = selectedPreset == amt;
            return GestureDetector(
              onTap: () => onPreset(amt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  gradient: sel ? AppTheme.primaryGradient : null,
                  color: sel ? null : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? Colors.transparent
                        : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '₦${amt.toInt()}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: sel ? Colors.white : null,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: customCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            hintText: 'Or enter custom amount',
            prefixText: '₦ ',
            prefixIcon: const Icon(Icons.edit_rounded),
            filled: true,
            fillColor: Theme.of(context).inputDecorationTheme.fillColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
          onChanged: (_) => onCustomChange(),
        ),
      ],
    );
  }
}

/// Summary row (label / value) used in pre-pay summary cards.
class _SummaryRow extends StatelessWidget {
  final String label, value;
  final bool highlight;
  const _SummaryRow(
      {required this.label, required this.value, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: highlight ? FontWeight.w900 : FontWeight.w600,
              fontSize: highlight ? 16 : 14,
              color: highlight ? AppTheme.primaryIndigo : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Root screen
// ─────────────────────────────────────────────────────────────────────────────

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({super.key});

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _onSuccess(BuildContext ctx, double amount) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.secondaryEmerald.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.secondaryEmerald, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              '₦${amount.toStringAsFixed(0)} Added!',
              style: Theme.of(ctx)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Your wallet has been credited successfully',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(ctx)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(ctx); // close sheet
                Navigator.pop(ctx); // go back
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Money'),
        backgroundColor: isDark
            ? AppTheme.darkBgGradient.colors.first
            : AppTheme.lightBgGradient.colors.first,
        bottom: TabBar(
          controller: _tab,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          indicatorColor: AppTheme.primaryIndigo,
          labelColor: AppTheme.primaryIndigo,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.credit_card_rounded), text: 'Card'),
            Tab(
                icon: Icon(Icons.account_balance_rounded),
                text: 'Bank Transfer'),
            Tab(icon: Icon(Icons.dialpad_rounded), text: 'USSD'),
            Tab(
                icon: Icon(Icons.phone_android_rounded),
                text: 'Virtual Account'),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: TabBarView(
          controller: _tab,
          children: [
            _CardTab(onSuccess: (amt) => _onSuccess(context, amt)),
            _BankTransferTab(onSuccess: (amt) => _onSuccess(context, amt)),
            _USSDTab(onSuccess: (amt) => _onSuccess(context, amt)),
            _VirtualAccountTab(onSuccess: (amt) => _onSuccess(context, amt)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. Card Tab
// ─────────────────────────────────────────────────────────────────────────────

class _CardTab extends StatefulWidget {
  final void Function(double) onSuccess;
  const _CardTab({required this.onSuccess});

  @override
  State<_CardTab> createState() => _CardTabState();
}

class _CardTabState extends State<_CardTab> {
  final _cardNum = TextEditingController();
  final _expiry = TextEditingController();
  final _cvv = TextEditingController();
  final _cardName = TextEditingController();
  final _customAmountCtrl = TextEditingController();
  final _networkSearchCtrl = TextEditingController();

  double? _selectedPreset;
  String? _selectedNetwork;
  String _networkQuery = '';
  bool _loading = false;

  static const _networks = [
    {'name': 'Visa', 'icon': Icons.credit_card_rounded, 'color': 0xFF1A1F71},
    {'name': 'Mastercard', 'icon': Icons.credit_card_rounded, 'color': 0xFFEB001B},
    {'name': 'Verve', 'icon': Icons.credit_card_rounded, 'color': 0xFF007B5E},
    {'name': 'American Express', 'icon': Icons.credit_card_rounded, 'color': 0xFF2E77BC},
    {'name': 'Union Pay', 'icon': Icons.credit_card_rounded, 'color': 0xFFE21836},
  ];

  double get _amount =>
      _selectedPreset ?? (double.tryParse(_customAmountCtrl.text) ?? 0);

  @override
  void dispose() {
    _cardNum.dispose();
    _expiry.dispose();
    _cvv.dispose();
    _cardName.dispose();
    _customAmountCtrl.dispose();
    _networkSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (_amount < 100) {
      _snack('Minimum amount is ₦100');
      return;
    }
    if (_cardNum.text.replaceAll(' ', '').length < 16) {
      _snack('Enter a valid 16-digit card number');
      return;
    }
    if (_cardName.text.trim().isEmpty) {
      _snack('Enter cardholder name');
      return;
    }
    if (_expiry.text.length < 5) {
      _snack('Enter card expiry (MM/YY)');
      return;
    }
    if (_cvv.text.length < 3) {
      _snack('Enter a valid CVV');
      return;
    }

    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.fundWallet(amount: _amount);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      widget.onSuccess(_amount);
    } else {
      _snack(auth.errorMessage ?? 'Payment failed');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  InputDecoration _dec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        counterText: '',
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Amount picker
          GlassCard(
            child: _AmountPicker(
              selectedPreset: _selectedPreset,
              customCtrl: _customAmountCtrl,
              onPreset: (v) => setState(() {
                _selectedPreset = v;
                _customAmountCtrl.clear();
              }),
              onCustomChange: () => setState(() => _selectedPreset = null),
            ),
          ),
          const SizedBox(height: 16),

          // Card network search
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Card Network', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 10),
                TextField(
                  controller: _networkSearchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search card network (Visa, Mastercard…)',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _networkQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _networkSearchCtrl.clear();
                              setState(() => _networkQuery = '');
                            })
                        : null,
                    filled: true,
                    fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _networkQuery = v),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _networks
                      .where((n) => (n['name'] as String)
                          .toLowerCase()
                          .contains(_networkQuery.toLowerCase()))
                      .map((n) {
                    final sel = _selectedNetwork == n['name'] as String;
                    final color = Color(n['color'] as int);
                    return GestureDetector(
                      onTap: () => setState(
                          () => _selectedNetwork = sel ? null : n['name'] as String),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: sel ? color.withValues(alpha: 0.12) : Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: sel ? color : Theme.of(context).dividerColor.withValues(alpha: 0.3),
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.credit_card_rounded, size: 16, color: sel ? color : Colors.grey),
                            const SizedBox(width: 6),
                            Text(n['name'] as String,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: sel ? color : null)),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Card details
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.credit_card_rounded,
                          color: AppTheme.primaryIndigo, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text('Card Details',
                        style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
                const SizedBox(height: 16),

                // Live card preview
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Icon(Icons.wifi_rounded, color: Colors.white70),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('VISA',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 2)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: _cardNum,
                        builder: (_, __, ___) {
                          final raw = _cardNum.text.replaceAll(' ', '');
                          final formatted = List.generate(4, (i) {
                            final chunk = raw.substring(
                                min(i * 4, raw.length),
                                min((i + 1) * 4, raw.length));
                            return chunk.isEmpty ? '••••' : chunk;
                          }).join('  ');
                          return Text(formatted,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 4));
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ValueListenableBuilder(
                            valueListenable: _cardName,
                            builder: (_, __, ___) => Text(
                              _cardName.text.isEmpty
                                  ? 'CARDHOLDER NAME'
                                  : _cardName.text.toUpperCase(),
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                          ValueListenableBuilder(
                            valueListenable: _expiry,
                            builder: (_, __, ___) => Text(
                              _expiry.text.isEmpty ? 'MM/YY' : _expiry.text,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Card number
                TextField(
                  controller: _cardNum,
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  decoration: _dec('Card Number', Icons.credit_card_rounded),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    _CardNumberFormatter(),
                  ],
                ),
                const SizedBox(height: 12),
                // Cardholder name
                TextField(
                  controller: _cardName,
                  textCapitalization: TextCapitalization.words,
                  decoration: _dec('Cardholder Name', Icons.person_rounded),
                ),
                const SizedBox(height: 12),
                // Expiry + CVV
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _expiry,
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        decoration:
                            _dec('MM/YY', Icons.calendar_today_rounded),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          _ExpiryFormatter(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _cvv,
                        keyboardType: TextInputType.number,
                        maxLength: 3,
                        obscureText: true,
                        decoration: _dec('CVV', Icons.lock_rounded),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Summary card
          if (_amount >= 100)
            GlassCard(
              child: Column(
                children: [
                  _SummaryRow(label: 'Method', value: 'Debit/Credit Card'),
                  const Divider(height: 16),
                  _SummaryRow(
                    label: 'Amount',
                    value: '₦${_amount.toStringAsFixed(0)}',
                    highlight: true,
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_rounded,
                  size: 14, color: AppTheme.secondaryEmerald),
              const SizedBox(width: 4),
              Text('256-bit SSL · PCI DSS Compliant',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppTheme.secondaryEmerald)),
            ],
          ),
          const SizedBox(height: 12),
          GradientButton(
            label: _amount >= 100
                ? 'Pay  ₦${_amount.toStringAsFixed(0)}'
                : 'Enter an amount to continue',
            isLoading: _loading,
            onPressed: _amount >= 100 ? _pay : null,
            icon: Icons.payment_rounded,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// Card number formatter (XXXX XXXX XXXX XXXX)
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    final digits = value.text.replaceAll(' ', '');
    final buf = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write(' ');
      buf.write(digits[i]);
    }
    final str = buf.toString();
    return value.copyWith(
        text: str,
        selection: TextSelection.collapsed(offset: str.length));
  }
}

// Expiry formatter (MM/YY)
class _ExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue old, TextEditingValue value) {
    var text = value.text.replaceAll('/', '');
    if (text.length > 4) text = text.substring(0, 4);
    if (text.length >= 3) {
      text = '${text.substring(0, 2)}/${text.substring(2)}';
    }
    return value.copyWith(
        text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. Bank Transfer Tab — debit from your bank account
// ─────────────────────────────────────────────────────────────────────────────

class _BankTransferTab extends StatefulWidget {
  final void Function(double) onSuccess;
  const _BankTransferTab({required this.onSuccess});

  @override
  State<_BankTransferTab> createState() => _BankTransferTabState();
}

class _BankTransferTabState extends State<_BankTransferTab> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _customAmountCtrl = TextEditingController();

  String? _selectedBank;
  String? _verifiedName;
  bool _verifying = false;
  bool _paying = false;
  double? _selectedPreset;

  @override
  void dispose() {
    _accountCtrl.dispose();
    _customAmountCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      _selectedPreset ?? (double.tryParse(_customAmountCtrl.text) ?? 0);

  void _resetVerification() {
    if (_verifiedName != null) setState(() => _verifiedName = null);
  }

  Future<void> _verifyAccount() async {
    if (_accountCtrl.text.length < 10 || _selectedBank == null) {
      _snack('Enter a 10-digit account number and select a bank');
      return;
    }
    setState(() {
      _verifying = true;
      _verifiedName = null;
    });
    try {
      final code = bankCode(_selectedBank!) ?? '';
      final result = await context.read<AuthProvider>().api.verifyAccount(
        accountNumber: _accountCtrl.text,
        bankCode: code,
      );
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifiedName = result['account_name'] as String? ?? 'Unknown Account';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _verifying = false;
        _verifiedName = null;
      });
      _snack('Could not verify account. Check the number and try again.');
    }
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedName == null) {
      _snack('Please verify your account number first');
      return;
    }
    if (_amount < 100) {
      _snack('Minimum amount is ₦100');
      return;
    }
    setState(() => _paying = true);
    final auth = context.read<AuthProvider>();
    final ok = await auth.fundWallet(amount: _amount);
    if (!mounted) return;
    setState(() => _paying = false);
    if (ok) {
      widget.onSuccess(_amount);
    } else {
      _snack(auth.errorMessage ?? 'Payment failed. Please try again.');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );

  InputDecoration _fieldDec(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: Theme.of(context).inputDecorationTheme.fillColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              const BorderSide(color: AppTheme.primaryIndigo, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Amount
            GlassCard(
              child: _AmountPicker(
                selectedPreset: _selectedPreset,
                customCtrl: _customAmountCtrl,
                onPreset: (v) => setState(() {
                  _selectedPreset = v;
                  _customAmountCtrl.clear();
                }),
                onCustomChange: () => setState(() => _selectedPreset = null),
              ),
            ),
            const SizedBox(height: 16),

            // Bank + account
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.account_balance_rounded,
                            color: AppTheme.primaryIndigo, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Text('Your Bank Account',
                          style: Theme.of(context).textTheme.titleMedium),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownSearch<String>(
                    items: (filter, _) => nigerianBankNames
                        .where((b) => b
                            .toLowerCase()
                            .contains(filter.toLowerCase()))
                        .toList(),
                    selectedItem: _selectedBank,
                    onChanged: (v) {
                      setState(() => _selectedBank = v);
                      _resetVerification();
                    },
                    decoratorProps: DropDownDecoratorProps(
                      decoration: _fieldDec(
                          'Select your bank', Icons.account_balance_rounded),
                    ),
                    popupProps: PopupProps.modalBottomSheet(
                      showSearchBox: true,
                      searchFieldProps: TextFieldProps(
                        decoration:
                            _fieldDec('Search bank...', Icons.search_rounded),
                      ),
                      modalBottomSheetProps: ModalBottomSheetProps(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.vertical(
                              top: Radius.circular(24)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _accountCtrl,
                          keyboardType: TextInputType.number,
                          maxLength: 10,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: _fieldDec(
                            'Account Number (10 digits)',
                            Icons.pin_rounded,
                          ).copyWith(counterText: ''),
                          onChanged: (_) => _resetVerification(),
                          validator: (v) {
                            if (v == null || v.length != 10) {
                              return 'Enter 10-digit account number';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _verifying ? null : _verifyAccount,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryIndigo,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 18),
                          ),
                          child: _verifying
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : const Text('Verify',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),

                  // Verified name badge
                  AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeInOut,
                    child: _verifiedName == null
                        ? const SizedBox.shrink()
                        : Container(
                            margin: const EdgeInsets.only(top: 10),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryEmerald
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: AppTheme.secondaryEmerald
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_rounded,
                                    color: AppTheme.secondaryEmerald,
                                    size: 20),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Account Verified',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.secondaryEmerald
                                                .withValues(alpha: 0.8))),
                                    Text(_verifiedName!,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: AppTheme.secondaryEmerald)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),

            // Summary
            if (_verifiedName != null && _amount >= 100) ...[
              const SizedBox(height: 16),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Transaction Summary',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 12),
                    _SummaryRow(
                        label: 'From', value: _selectedBank ?? '—'),
                    _SummaryRow(
                        label: 'Account',
                        value: _accountCtrl.text.isNotEmpty
                            ? _accountCtrl.text
                            : '—'),
                    _SummaryRow(
                        label: 'Name', value: _verifiedName ?? '—'),
                    const Divider(height: 20),
                    _SummaryRow(
                        label: 'Amount',
                        value: '₦${_amount.toStringAsFixed(0)}',
                        highlight: true),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            GradientButton(
              label: _verifiedName == null
                  ? 'Verify Account First'
                  : 'Fund Wallet  ₦${_amount >= 100 ? _amount.toStringAsFixed(0) : '—'}',
              isLoading: _paying,
              onPressed: _verifiedName == null ? null : _pay,
              icon: Icons.bolt_rounded,
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '🔒 Your bank details are encrypted and never stored',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. USSD Tab — amount + bank → pre-filled USSD code → dial
// ─────────────────────────────────────────────────────────────────────────────

class _USSDTab extends StatefulWidget {
  final void Function(double) onSuccess;
  const _USSDTab({required this.onSuccess});

  @override
  State<_USSDTab> createState() => _USSDTabState();
}

class _USSDTabState extends State<_USSDTab> {
  final _customAmountCtrl = TextEditingController();
  final _bankSearchCtrl = TextEditingController();
  double? _selectedPreset;
  String _bankQuery = '';

  // All banks with USSD templates (AMOUNT placeholder replaced at runtime)
  static const _ussdBanks = [
    {'bank': 'GTBank', 'template': '*737*50*AMOUNT*0#', 'color': 0xFFFF5722},
    {
      'bank': 'Access Bank',
      'template': '*901*AMOUNT#',
      'color': 0xFFE91E63
    },
    {'bank': 'First Bank', 'template': '*894*AMOUNT#', 'color': 0xFF009688},
    {
      'bank': 'Zenith Bank',
      'template': '*966*AMOUNT#',
      'color': 0xFF3F51B5
    },
    {'bank': 'UBA', 'template': '*919*3*AMOUNT#', 'color': 0xFFFF9800},
    {'bank': 'Wema Bank', 'template': '*945*AMOUNT#', 'color': 0xFF673AB7},
    {
      'bank': 'Fidelity Bank',
      'template': '*770*AMOUNT#',
      'color': 0xFF4CAF50
    },
    {
      'bank': 'Sterling Bank',
      'template': '*822*4*AMOUNT#',
      'color': 0xFFF44336
    },
    {
      'bank': 'Stanbic IBTC',
      'template': '*909*AMOUNT#',
      'color': 0xFF2196F3
    },
    {
      'bank': 'Keystone Bank',
      'template': '*7111*AMOUNT#',
      'color': 0xFF795548
    },
    {'bank': 'FCMB', 'template': '*329*AMOUNT#', 'color': 0xFF00BCD4},
    {
      'bank': 'Union Bank',
      'template': '*826*AMOUNT#',
      'color': 0xFF8BC34A
    },
    {'bank': 'Ecobank', 'template': '*326*AMOUNT#', 'color': 0xFF607D8B},
    {
      'bank': 'Polaris Bank',
      'template': '*833*AMOUNT#',
      'color': 0xFF9C27B0
    },
    {
      'bank': 'Heritage Bank',
      'template': '*322*AMOUNT#',
      'color': 0xFFFF5252
    },
    {'bank': 'Unity Bank', 'template': '*7799*AMOUNT#', 'color': 0xFF009688},
    {
      'bank': 'Diamond Bank',
      'template': '*426*AMOUNT#',
      'color': 0xFF3F51B5
    },
  ];

  double get _amount =>
      _selectedPreset ?? (double.tryParse(_customAmountCtrl.text) ?? 0);

  String _buildCode(String template) =>
      template.replaceAll('AMOUNT', _amount.toInt().toString());

  void _copyCode(String code) {
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('USSD code copied!'),
          behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _onConfirmDial(String bank, double amount) async {
    // Brief pause to feel like the phone dialler was opened
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Show "I've completed the USSD" confirm → credit wallet
    final done = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.primaryIndigo.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.dialpad_rounded,
                  color: AppTheme.primaryIndigo, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Dial the USSD Code',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Open your phone dialler and call the code shown on the previous screen. Once completed, tap "I\'ve Done It".',
              style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: "I've Done It — Add ₦${amount.toInt()} to Wallet",
              icon: Icons.check_circle_rounded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("Cancel"),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (done == true && mounted) {
      final auth = context.read<AuthProvider>();
      final ok = await auth.fundWallet(amount: amount);
      if (!mounted) return;
      if (ok) {
        widget.onSuccess(amount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(auth.errorMessage ?? 'Funding failed'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    _bankSearchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasAmount = _amount >= 100;
    final filtered = _bankQuery.isEmpty
        ? _ussdBanks
        : _ussdBanks
            .where((b) => (b['bank'] as String)
                .toLowerCase()
                .contains(_bankQuery.toLowerCase()))
            .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              // Amount picker
              GlassCard(
                child: _AmountPicker(
                  selectedPreset: _selectedPreset,
                  customCtrl: _customAmountCtrl,
                  onPreset: (v) => setState(() {
                    _selectedPreset = v;
                    _customAmountCtrl.clear();
                  }),
                  onCustomChange: () =>
                      setState(() => _selectedPreset = null),
                ),
              ),
              const SizedBox(height: 12),

              // Bank search field
              TextField(
                controller: _bankSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search bank name…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _bankQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _bankSearchCtrl.clear();
                            setState(() => _bankQuery = '');
                          })
                      : null,
                  filled: true,
                  fillColor: Theme.of(context).inputDecorationTheme.fillColor,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onChanged: (v) => setState(() => _bankQuery = v),
              ),
              const SizedBox(height: 6),
              Text(
                hasAmount
                    ? '${filtered.length} bank${filtered.length == 1 ? '' : 's'} — tap 📞 to dial ₦${_amount.toInt()}'
                    : 'Enter an amount above, then tap 📞 to dial',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppTheme.primaryIndigo),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final c = filtered[i];
              final color = Color(c['color'] as int);
              final template = c['template'] as String;
              final code = hasAmount
                  ? _buildCode(template)
                  : template;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.dialpad_rounded,
                            color: color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c['bank'] as String,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            Text(
                              code,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: hasAmount ? color : Colors.grey,
                                fontSize: 14,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Copy
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        tooltip: 'Copy code',
                        onPressed: () => _copyCode(code),
                      ),
                      // Dial
                      IconButton(
                        icon: Icon(
                          Icons.phone_rounded,
                          color: hasAmount ? color : Colors.grey,
                          size: 22,
                        ),
                        tooltip: hasAmount
                            ? 'Dial & fund wallet'
                            : 'Enter amount first',
                        onPressed: hasAmount
                            ? () => _onConfirmDial(c['bank'] as String, _amount)
                            : null,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }


}

// ─────────────────────────────────────────────────────────────────────────────
// 4. Virtual Account Tab — amount → show account → user transfers → confirm
// ─────────────────────────────────────────────────────────────────────────────

class _VirtualAccountTab extends StatefulWidget {
  final void Function(double) onSuccess;
  const _VirtualAccountTab({required this.onSuccess});

  @override
  State<_VirtualAccountTab> createState() => _VirtualAccountTabState();
}

class _VirtualAccountTabState extends State<_VirtualAccountTab> {
  final _customAmountCtrl = TextEditingController();
  final _bankSearchCtrl = TextEditingController();
  double? _selectedPreset;
  String _bankQuery = '';
  bool _loading = false;
  bool _accountsLoading = true;
  List<Map<String, dynamic>> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _accountsLoading = true);
    try {
      final accounts = await context.read<AuthProvider>().api.getVirtualAccounts();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _accountsLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _accountsLoading = false);
    }
  }

  @override
  void dispose() {
    _customAmountCtrl.dispose();
    _bankSearchCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      _selectedPreset ?? (double.tryParse(_customAmountCtrl.text) ?? 0);

  void _copy(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('$label copied!'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _confirmTransfer() async {
    if (_amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter an amount first'),
            behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Show "I've transferred" confirmation sheet
    final done = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(ctx).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.secondaryEmerald.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded,
                  color: AppTheme.secondaryEmerald, size: 36),
            ),
            const SizedBox(height: 16),
            Text('Confirm Transfer',
                style: Theme.of(ctx)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              'Have you sent exactly ₦${_amount.toInt()} to one of the virtual accounts above?',
              style: Theme.of(ctx)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: "Yes, I've Sent ₦${_amount.toInt()}",
              icon: Icons.check_rounded,
              onPressed: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Not yet'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (done == true && mounted) {
      setState(() => _loading = true);
      final auth = context.read<AuthProvider>();
      final ok = await auth.fundWallet(amount: _amount);
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        widget.onSuccess(_amount);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(auth.errorMessage ?? 'Funding failed'),
              behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_accountsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_accounts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text('Could not load virtual accounts'),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _loadAccounts,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final hasAmount = _amount >= 100;
    final filteredAccounts = _bankQuery.isEmpty
        ? _accounts
        : _accounts
            .where((a) => (a['bank'] as String)
                .toLowerCase()
                .contains(_bankQuery.toLowerCase()))
            .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        children: [
          // Amount picker
          GlassCard(
            child: _AmountPicker(
              selectedPreset: _selectedPreset,
              customCtrl: _customAmountCtrl,
              onPreset: (v) => setState(() {
                _selectedPreset = v;
                _customAmountCtrl.clear();
              }),
              onCustomChange: () => setState(() => _selectedPreset = null),
            ),
          ),
          const SizedBox(height: 16),

          // Info banner
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.warningAmber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.warningAmber.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.warningAmber, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasAmount
                        ? 'Transfer exactly ₦${_amount.toInt()} to any account below. Then tap "I\'ve Transferred".'
                        : 'Enter an amount above, then transfer to any account below.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: AppTheme.warningAmber),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bank search field
          TextField(
            controller: _bankSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search bank name…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _bankQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _bankSearchCtrl.clear();
                        setState(() => _bankQuery = '');
                      })
                  : null,
              filled: true,
              fillColor: Theme.of(context).inputDecorationTheme.fillColor,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (v) => setState(() => _bankQuery = v),
          ),
          const SizedBox(height: 8),
          Text(
            '${filteredAccounts.length} virtual account${filteredAccounts.length == 1 ? '' : 's'} available',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.primaryIndigo),
          ),
          const SizedBox(height: 12),

          // Virtual accounts
          ...filteredAccounts.map((acc) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF10B981), Color(0xFF34D399)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AppTheme.secondaryEmerald.withValues(alpha: 0.25),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color:
                                  Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.account_balance_rounded,
                                color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(acc['bank']!,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text('Account Number',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 11)),
                      const SizedBox(height: 4),
                      Text(acc['number']!,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4)),
                      const SizedBox(height: 2),
                      Text(acc['name']!,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontSize: 12)),
                      if (hasAmount) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Send exactly  ₦${_amount.toInt()}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13),
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _GhostBtn(
                              label: 'Copy Account',
                              icon: Icons.copy_rounded,
                              onTap: () =>
                                  _copy(acc['number']!, 'Account number'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _GhostBtn(
                              label: 'Copy Bank',
                              icon: Icons.account_balance_outlined,
                              onTap: () => _copy(acc['bank']!, 'Bank name'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              )),

          const SizedBox(height: 8),
          GradientButton(
            label: hasAmount
                ? "I've Transferred  ₦${_amount.toInt()}"
                : 'Enter an amount to continue',
            isLoading: _loading,
            onPressed: hasAmount ? _confirmTransfer : null,
            icon: Icons.check_circle_rounded,
          ),
          const SizedBox(height: 12),
          Text(
            'Wallet is credited within 60 seconds of your transfer being confirmed.',
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GhostBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _GhostBtn(
      {required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border:
              Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
