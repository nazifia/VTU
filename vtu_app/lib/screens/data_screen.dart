import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../widgets/contact_picker.dart';
import '../config/theme.dart';
import '../utils/currency_formatter.dart';

class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  String? _selectedProvider;
  _DataBundle? _selectedBundle;
  bool _loading = false;
  bool _forSelf = true;

  static const _providers = [
    {'name': 'MTN', 'color': Color(0xFFFFCC00)},
    {'name': 'Glo', 'color': Color(0xFF00A651)},
    {'name': 'Airtel', 'color': Color(0xFFD2222D)},
    {'name': '9mobile', 'color': Color(0xFF006633)},
  ];

  // All possible bundles — availability varies by provider
  static const _allBundles = <_DataBundle>[
    _DataBundle('500MB', 100, '1 Day'),
    _DataBundle('1GB', 200, '7 Days'),
    _DataBundle('2GB', 500, '30 Days'),
    _DataBundle('5GB', 1000, '30 Days'),
    _DataBundle('10GB', 2000, '30 Days'),
    _DataBundle('20GB', 3500, '30 Days'),
  ];

  List<_DataBundle> get _bundles {
    switch (_selectedProvider) {
      case '9mobile':
        return _allBundles
            .where((b) => !['10GB', '20GB'].contains(b.size))
            .toList();
      case 'Glo':
      case 'Airtel':
        return _allBundles.where((b) => b.size != '20GB').toList();
      default:
        return List.from(_allBundles);
    }
  }

  String _planId(_DataBundle bundle) {
    final provider = (_selectedProvider ?? '').toLowerCase();
    final size = bundle.size.toLowerCase();
    final validity = bundle.validity.toLowerCase().replaceAll(' ', '');
    return '${provider}_${size}_$validity';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_forSelf && _phoneCtrl.text.isEmpty) {
      final selfPhone = context.read<AuthProvider>().user?.phone ?? '';
      _phoneCtrl.text = selfPhone
          .replaceAll('+234', '0')
          .replaceAll(RegExp(r'^\+'), '');
    }
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<String?> _askTransactionPin() {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PinSheet(
        bundleSize: _selectedBundle?.size ?? '',
        phone: _phoneCtrl.text,
      ),
    );
  }

  Future<void> _buyData() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a network provider')),
      );
      return;
    }
    if (_selectedBundle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a data bundle')),
      );
      return;
    }

    final amount = _selectedBundle!.price.toDouble();
    final balance = context.read<AuthProvider>().user?.balance ?? 0;
    if (amount > balance) {
      _showInsufficientBalanceSheet(amount, balance);
      return;
    }

    final pin = await _askTransactionPin();
    if (pin == null || !mounted) return;

    setState(() => _loading = true);
    final success = await context.read<AuthProvider>().purchaseData(
          phone: _phoneCtrl.text.trim(),
          provider: _selectedProvider!,
          planId: _planId(_selectedBundle!),
          amount: amount,
          transactionPin: pin,
        );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        _showSuccessSheet();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.read<AuthProvider>().errorMessage ?? 'Purchase failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showInsufficientBalanceSheet(double required, double current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.account_balance_wallet_rounded,
                  color: AppTheme.errorRed, size: 36),
            ),
            const SizedBox(height: 16),
            const Text('Insufficient Balance',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              'You need ${required.formatCurrency} but your wallet balance is ${current.formatCurrency}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Fund Wallet',
              icon: Icons.add_circle_rounded,
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/fund-wallet');
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showSuccessSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.secondaryEmerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_rounded,
                  color: AppTheme.secondaryEmerald, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Purchase Successful!',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
            const SizedBox(height: 8),
            Text(
              '${_selectedBundle!.size} data sent to ${_phoneCtrl.text} via $_selectedProvider',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Done',
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
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
    const dataColor = Color(0xFF8B5CF6);
    final bundles = _bundles;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Buy Data'),
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
                        // ── Network selector ───────────────────────────────
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Network',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              DropdownSearch<String>(
                                items: (filter, _) => _providers
                                    .map((p) => p['name'] as String)
                                    .where((n) => n
                                        .toLowerCase()
                                        .contains(filter.toLowerCase()))
                                    .toList(),
                                selectedItem: _selectedProvider,
                                decoratorProps: DropDownDecoratorProps(
                                  decoration: InputDecoration(
                                    labelText: 'Network Provider',
                                    prefixIcon: const Icon(
                                        Icons.signal_cellular_alt_rounded),
                                    filled: true,
                                    fillColor: Theme.of(context)
                                        .inputDecorationTheme
                                        .fillColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                                popupProps: PopupProps.menu(
                                  showSearchBox: true,
                                  searchFieldProps: TextFieldProps(
                                    decoration: InputDecoration(
                                      hintText: 'Search provider...',
                                      prefixIcon:
                                          const Icon(Icons.search_rounded),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  itemBuilder: (ctx, name, isSelected, _) {
                                    final p = _providers
                                        .firstWhere((x) => x['name'] == name);
                                    final color = p['color'] as Color;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            color.withValues(alpha: 0.2),
                                        child: Text(
                                          name[0],
                                          style: TextStyle(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      title: Text(
                                        name,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: isSelected ? color : null,
                                        ),
                                      ),
                                      trailing: isSelected
                                          ? Icon(Icons.check_circle_rounded,
                                              color: color)
                                          : null,
                                    );
                                  },
                                  menuProps: MenuProps(
                                    borderRadius: BorderRadius.circular(16),
                                    elevation: 8,
                                  ),
                                ),
                                onChanged: (v) => setState(() {
                                  _selectedProvider = v;
                                  _selectedBundle = null;
                                }),
                                validator: (v) =>
                                    v == null ? 'Select a provider' : null,
                              ),
                              // Visual quick-select row
                              const SizedBox(height: 16),
                              Row(
                                children: _providers.map((p) {
                                  final name = p['name'] as String;
                                  final color = p['color'] as Color;
                                  final selected = _selectedProvider == name;
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4),
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _selectedProvider = name;
                                          _selectedBundle = null;
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 12),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? color.withValues(alpha: 0.18)
                                                : Colors.transparent,
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color: selected
                                                  ? color
                                                  : Theme.of(context)
                                                      .dividerColor
                                                      .withValues(alpha: 0.3),
                                              width: selected ? 2 : 1,
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              CircleAvatar(
                                                radius: 16,
                                                backgroundColor:
                                                    color.withValues(alpha: 0.2),
                                                child: Text(
                                                  name[0],
                                                  style: TextStyle(
                                                    color: color,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w400,
                                                  color:
                                                      selected ? color : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Phone number ───────────────────────────────────
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone Number',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              Container(
                                decoration: BoxDecoration(
                                  color:
                                      Theme.of(context).colorScheme.surface,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          final selfPhone = context
                                                  .read<AuthProvider>()
                                                  .user
                                                  ?.phone ??
                                              '';
                                          setState(() {
                                            _forSelf = true;
                                            _phoneCtrl.text = selfPhone
                                                .replaceAll('+234', '0')
                                                .replaceAll(
                                                    RegExp(r'^\+'), '');
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: _forSelf
                                                ? AppTheme.primaryGradient
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.person_rounded,
                                                  size: 16,
                                                  color: _forSelf
                                                      ? Colors.white
                                                      : null),
                                              const SizedBox(width: 6),
                                              Text('Self',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: _forSelf
                                                        ? Colors.white
                                                        : null,
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () => setState(() {
                                          _forSelf = false;
                                          _phoneCtrl.clear();
                                        }),
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                              milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 10),
                                          decoration: BoxDecoration(
                                            gradient: !_forSelf
                                                ? AppTheme.primaryGradient
                                                : null,
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(Icons.people_rounded,
                                                  size: 16,
                                                  color: !_forSelf
                                                      ? Colors.white
                                                      : null),
                                              const SizedBox(width: 6),
                                              Text('Others',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: !_forSelf
                                                        ? Colors.white
                                                        : null,
                                                  )),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: _phoneCtrl,
                                      label: _forSelf
                                          ? 'My Number'
                                          : 'Recipient Number',
                                      hint: '08012345678',
                                      prefixIcon: Icons.phone_android_rounded,
                                      keyboardType: TextInputType.phone,
                                      readOnly: _forSelf,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      validator: (v) {
                                        if (v!.isEmpty) {
                                          return 'Phone number required';
                                        }
                                        if (v.length < 11) {
                                          return 'Enter valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  if (!_forSelf) ...[
                                    const SizedBox(width: 8),
                                    IconButton.filled(
                                      tooltip: 'Pick from contacts',
                                      style: IconButton.styleFrom(
                                        backgroundColor: dataColor
                                            .withValues(alpha: 0.12),
                                        foregroundColor: dataColor,
                                      ),
                                      icon: const Icon(Icons.contacts_rounded),
                                      onPressed: () async {
                                        final phone =
                                            await pickContactPhone(context);
                                        if (phone != null) {
                                          setState(
                                              () => _phoneCtrl.text = phone);
                                        }
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // ── Bundle selection ───────────────────────────────
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Bundle',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              if (_selectedProvider == null)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                  child: Text(
                                    'Select a network provider to see available bundles',
                                    style: TextStyle(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.5),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                )
                              else
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: bundles.map((bundle) {
                                    final isSelected =
                                        _selectedBundle == bundle;
                                    return GestureDetector(
                                      onTap: () => setState(
                                          () => _selectedBundle = bundle),
                                      child: AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          gradient: isSelected
                                              ? const LinearGradient(
                                                  colors: [
                                                    dataColor,
                                                    Color(0xFF6D28D9),
                                                  ],
                                                )
                                              : null,
                                          color: isSelected
                                              ? null
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .surface,
                                          borderRadius:
                                              BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isSelected
                                                ? Colors.transparent
                                                : Theme.of(context)
                                                    .dividerColor
                                                    .withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              bundle.size,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w800,
                                                fontSize: 15,
                                                color: isSelected
                                                    ? Colors.white
                                                    : dataColor,
                                              ),
                                            ),
                                            Text(
                                              bundle.price.formatCurrency,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12,
                                                color: isSelected
                                                    ? Colors.white70
                                                    : null,
                                              ),
                                            ),
                                            Text(
                                              bundle.validity,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: isSelected
                                                    ? Colors.white60
                                                    : Theme.of(context)
                                                        .colorScheme
                                                        .onSurface
                                                        .withValues(alpha: 0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Buy Data',
                          onPressed: _buyData,
                          isLoading: _loading,
                          icon: Icons.wifi_rounded,
                        ),
                        const SizedBox(height: 20),
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
}

// ── PIN entry sheet ──────────────────────────────────────────────────────────
// Extracted into its own StatefulWidget so Flutter properly disposes the
// InputDecorator animation tickers when the sheet is dismissed, preventing
// the "dirty widget outside build scope" assertion.
class _PinSheet extends StatefulWidget {
  const _PinSheet({required this.bundleSize, required this.phone});
  final String bundleSize;
  final String phone;

  @override
  State<_PinSheet> createState() => _PinSheetState();
}

class _PinSheetState extends State<_PinSheet> {
  final _pinCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter Transaction PIN',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            const SizedBox(height: 6),
            Text(
              'Confirm purchase of ${widget.bundleSize} data for ${widget.phone}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _pinCtrl,
              obscureText: true,
              keyboardType: TextInputType.number,
              maxLength: 6,
              autofocus: true,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Transaction PIN',
                prefixIcon: const Icon(Icons.lock_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Confirm Purchase',
              icon: Icons.check_rounded,
              onPressed: () {
                if (_pinCtrl.text.length < 4) return;
                Navigator.pop(context, _pinCtrl.text);
              },
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataBundle {
  final String size;
  final int price;
  final String validity;

  const _DataBundle(this.size, this.price, this.validity);

  @override
  bool operator ==(Object other) =>
      other is _DataBundle &&
      size == other.size &&
      validity == other.validity;

  @override
  int get hashCode => Object.hash(size, validity);
}
