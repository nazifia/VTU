import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/contact_picker.dart';
import '../config/theme.dart';
import '../config/banks.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _narrationCtrl = TextEditingController();

  String? _selectedBank;
  String? _verifiedName;
  bool _verifying = false;
  bool _loading = false;
  double? _selectedPreset;

  static const _presets = [500.0, 1000.0, 2000.0, 5000.0, 10000.0, 20000.0];

  @override
  void dispose() {
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    _narrationCtrl.dispose();
    super.dispose();
  }

  double get _amount =>
      _selectedPreset ?? (double.tryParse(_amountCtrl.text) ?? 0);

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

  Future<void> _submitTransfer() async {
    if (!_formKey.currentState!.validate()) return;
    if (_verifiedName == null) {
      _snack('Please verify the account number first');
      return;
    }
    if (_amount < 100) {
      _snack('Minimum transfer is ₦100');
      return;
    }

    // Show confirmation bottom sheet
    final confirmed = await _showConfirmSheet();
    if (!confirmed || !mounted) return;

    setState(() => _loading = true);
    final code = bankCode(_selectedBank ?? '') ?? '';
    final auth = context.read<AuthProvider>();
    final success = await auth.bankTransfer(
      accountNumber: _accountCtrl.text.trim(),
      bankCode: code,
      amount: _amount,
      narration: _narrationCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      _showSuccessSheet();
    } else {
      _snack(auth.errorMessage ?? 'Transfer failed. Please try again.');
    }
  }

  Future<bool> _showConfirmSheet() async {
    return await showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                Text('Confirm Transfer',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                _confirmRow('To', _verifiedName ?? '—'),
                _confirmRow('Bank', _selectedBank ?? '—'),
                _confirmRow('Account', _accountCtrl.text),
                if (_narrationCtrl.text.isNotEmpty)
                  _confirmRow('Note', _narrationCtrl.text),
                const Divider(height: 24),
                _confirmRow(
                  'Amount',
                  '₦${_amount.toStringAsFixed(0)}',
                  highlight: true,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: GradientButton(
                        label: 'Send Money',
                        icon: Icons.send_rounded,
                        onPressed: () => Navigator.pop(context, true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ) ??
        false;
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      builder: (_) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
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
              '₦${_amount.toStringAsFixed(0)} Sent!',
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Transfer to $_verifiedName was successful',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            GradientButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context); // close sheet
                Navigator.pop(context); // go back
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _confirmRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
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
              fontSize: highlight ? 17 : 14,
              color: highlight ? AppTheme.primaryIndigo : null,
            ),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Bank Transfer'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Step 1: Amount ───────────────────────────────
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryIndigo
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.attach_money_rounded,
                                        color: AppTheme.primaryIndigo,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Amount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              const SizedBox(height: 14),
                              // Quick presets
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _presets.map((amt) {
                                  final sel = _selectedPreset == amt;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedPreset = amt;
                                      _amountCtrl.clear();
                                    }),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 160),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: sel
                                            ? AppTheme.primaryGradient
                                            : null,
                                        color: sel
                                            ? null
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius:
                                            BorderRadius.circular(10),
                                        border: Border.all(
                                          color: sel
                                              ? Colors.transparent
                                              : Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.3),
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
                              // Custom amount
                              TextFormField(
                                controller: _amountCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9.]')),
                                ],
                                decoration: _fieldDec(
                                    'Or enter custom amount (₦)',
                                    Icons.edit_rounded),
                                onChanged: (_) {
                                  setState(() => _selectedPreset = null);
                                },
                                validator: (_) {
                                  if (_amount < 100) {
                                    return 'Minimum transfer is ₦100';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Step 2: Recipient Details ────────────────────
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primaryIndigo
                                          .withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                        Icons.account_balance_rounded,
                                        color: AppTheme.primaryIndigo,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 10),
                                  Text('Recipient Details',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Bank dropdown
                              DropdownSearch<String>(
                                items: (filter, _) => nigerianBankNames
                                    .where((name) => name
                                        .toLowerCase()
                                        .contains(filter.toLowerCase()))
                                    .toList(),
                                selectedItem: _selectedBank,
                                decoratorProps: DropDownDecoratorProps(
                                  decoration: _fieldDec(
                                      'Select recipient\'s bank',
                                      Icons.account_balance_rounded),
                                ),
                                popupProps:
                                    PopupProps.modalBottomSheet(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: _fieldDec(
                                        'Search bank...',
                                        Icons.search_rounded),
                                  ),
                                  modalBottomSheetProps:
                                      ModalBottomSheetProps(
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                          top: Radius.circular(24)),
                                    ),
                                  ),
                                ),
                                onChanged: (v) {
                                  setState(() => _selectedBank = v);
                                  _resetVerification();
                                },
                              ),
                              const SizedBox(height: 12),

                              // Account number + contact picker
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _accountCtrl,
                                      keyboardType: TextInputType.number,
                                      maxLength: 10,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: _fieldDec(
                                        'Account Number (10 digits)',
                                        Icons.credit_card_rounded,
                                      ).copyWith(counterText: ''),
                                      onChanged: (_) => _resetVerification(),
                                      validator: (v) {
                                        if (v == null || v.isEmpty) {
                                          return 'Account number required';
                                        }
                                        if (v.length != 10) {
                                          return 'Must be 10 digits';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  // Contact picker
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: IconButton.filled(
                                      tooltip: 'Pick from contacts',
                                      style: IconButton.styleFrom(
                                        backgroundColor: AppTheme.primaryIndigo
                                            .withValues(alpha: 0.12),
                                        foregroundColor:
                                            AppTheme.primaryIndigo,
                                        minimumSize: const Size(52, 52),
                                      ),
                                      icon: const Icon(Icons.contacts_rounded),
                                      onPressed: () async {
                                        final phone =
                                            await pickContactPhone(context);
                                        if (phone != null) {
                                          _accountCtrl.text = phone;
                                          _resetVerification();
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  // Verify button
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: SizedBox(
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _verifying
                                            ? null
                                            : _verifyAccount,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.primaryIndigo,
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 14),
                                        ),
                                        child: _verifying
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                  color: Colors.white,
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Verify',
                                                style: TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 13)),
                                      ),
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
                                        margin:
                                            const EdgeInsets.only(top: 10),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 12),
                                        decoration: BoxDecoration(
                                          color: AppTheme.secondaryEmerald
                                              .withValues(alpha: 0.10),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                              color: AppTheme.secondaryEmerald
                                                  .withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                                Icons.check_circle_rounded,
                                                color:
                                                    AppTheme.secondaryEmerald,
                                                size: 20),
                                            const SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Account Verified',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: AppTheme
                                                        .secondaryEmerald
                                                        .withValues(alpha: 0.8),
                                                  ),
                                                ),
                                                Text(
                                                  _verifiedName!,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: AppTheme
                                                        .secondaryEmerald,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                              ),

                              const SizedBox(height: 14),

                              // Narration (optional)
                              TextField(
                                controller: _narrationCtrl,
                                decoration: _fieldDec(
                                    'Narration (optional)',
                                    Icons.edit_note_rounded),
                                textInputAction: TextInputAction.done,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Summary card (shown when ready) ──────────────
                        AnimatedSize(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeInOut,
                          child: _verifiedName == null || _amount < 100
                              ? const SizedBox.shrink()
                              : GlassCard(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Transaction Summary',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall),
                                      const SizedBox(height: 12),
                                      _summaryRow(context, 'To Bank',
                                          _selectedBank ?? '—'),
                                      _summaryRow(context, 'Account',
                                          _accountCtrl.text),
                                      _summaryRow(context, 'Name',
                                          _verifiedName ?? '—'),
                                      if (_narrationCtrl.text.isNotEmpty)
                                        _summaryRow(context, 'Note',
                                            _narrationCtrl.text),
                                      const Divider(height: 20),
                                      _summaryRow(
                                        context,
                                        'Amount',
                                        '₦${_amount.toStringAsFixed(0)}',
                                        highlight: true,
                                      ),
                                    ],
                                  ),
                                ),
                        ),

                        const SizedBox(height: 16),

                        // ── Send button ───────────────────────────────────
                        GradientButton(
                          label: _verifiedName == null
                              ? 'Verify Account First'
                              : 'Send  ₦${_amount >= 100 ? _amount.toStringAsFixed(0) : '—'}',
                          onPressed: _verifiedName == null ? null : _submitTransfer,
                          isLoading: _loading,
                          icon: Icons.send_rounded,
                        ),

                        const SizedBox(height: 12),
                        Center(
                          child: Text(
                            '🔒 End-to-end encrypted · Powered by CBN licensed rails',
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {bool highlight = false}) {
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
              fontWeight:
                  highlight ? FontWeight.w900 : FontWeight.w600,
              fontSize: highlight ? 16 : 14,
              color: highlight ? AppTheme.primaryIndigo : null,
            ),
          ),
        ],
      ),
    );
  }
}
