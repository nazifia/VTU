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

class AirtimeScreen extends StatefulWidget {
  const AirtimeScreen({super.key});

  @override
  State<AirtimeScreen> createState() => _AirtimeScreenState();
}

class _AirtimeScreenState extends State<AirtimeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _customAmountCtrl = TextEditingController();
  String? _selectedProvider;
  double? _selectedAmount;
  bool _loading = false;

  static const _providers = [
    {'name': 'MTN', 'color': Color(0xFFFFCC00), 'icon': '🔵'},
    {'name': 'Glo', 'color': Color(0xFF00A651), 'icon': '🟢'},
    {'name': 'Airtel', 'color': Color(0xFFD2222D), 'icon': '🔴'},
    {'name': '9mobile', 'color': Color(0xFF006633), 'icon': '🟩'},
  ];

  static const _presets = [200.0, 500.0, 1000.0, 2000.0, 5000.0];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _customAmountCtrl.dispose();
    super.dispose();
  }

  Future<void> _buyAirtime() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProvider == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a network provider')),
      );
      return;
    }
    final amount = _selectedAmount ?? double.tryParse(_customAmountCtrl.text);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or enter an amount')),
      );
      return;
    }

    setState(() => _loading = true);
    final success = await context.read<AuthProvider>().purchaseAirtime(
          phone: _phoneCtrl.text.trim(),
          provider: _selectedProvider!,
          amount: amount,
        );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        _showSuccessSheet(amount);
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

  void _showSuccessSheet(double amount) {
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
              '${amount.formatCurrency} $_selectedProvider airtime sent to ${_phoneCtrl.text}',
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

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              AppBar(
                title: const Text('Buy Airtime'),
                backgroundColor: Colors.transparent,
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 8),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Provider searchable dropdown
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Network',
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              DropdownSearch<String>(
                                items: (filter, _) => _providers
                                    .map((p) => p['name'] as String)
                                    .where((name) => name
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
                                    final p = _providers.firstWhere(
                                        (x) => x['name'] == name);
                                    final color = p['color'] as Color;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        radius: 16,
                                        backgroundColor:
                                            color.withValues(alpha: 0.2),
                                        child: Text(
                                          (name as String)[0],
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
                                          color:
                                              isSelected ? color : null,
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
                                onChanged: (v) =>
                                    setState(() => _selectedProvider = v),
                                validator: (v) =>
                                    v == null ? 'Select a provider' : null,
                              ),
                              // Visual quick-select row below
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
                                        onTap: () => setState(
                                            () => _selectedProvider = name),
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
                                              Text(name,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: selected
                                                        ? FontWeight.w700
                                                        : FontWeight.w400,
                                                    color: selected
                                                        ? color
                                                        : null,
                                                  )),
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
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone Number',
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                             Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: CustomTextField(
                                      controller: _phoneCtrl,
                                      label: 'Phone Number',
                                      hint: '08012345678',
                                      prefixIcon: Icons.phone_android_rounded,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      validator: (v) {
                                        if (v!.isEmpty) return 'Phone number required';
                                        if (v.length < 11) return 'Enter valid phone number';
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    tooltip: 'Pick from contacts',
                                    style: IconButton.styleFrom(
                                      backgroundColor: AppTheme.primaryIndigo
                                          .withValues(alpha: 0.12),
                                      foregroundColor: AppTheme.primaryIndigo,
                                    ),
                                    icon: const Icon(Icons.contacts_rounded),
                                    onPressed: () async {
                                      final phone =
                                          await pickContactPhone(context);
                                      if (phone != null) {
                                        setState(() => _phoneCtrl.text = phone);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Amount selection
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Amount',
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: _presets.map((amt) {
                                  final selected = _selectedAmount == amt;
                                  return GestureDetector(
                                    onTap: () => setState(() {
                                      _selectedAmount = amt;
                                      _customAmountCtrl.clear();
                                    }),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        gradient: selected
                                            ? AppTheme.primaryGradient
                                            : null,
                                        color: selected
                                            ? null
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? Colors.transparent
                                              : Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Text(
                                        amt.formatCurrency,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: selected ? Colors.white : null,
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _customAmountCtrl,
                                label: 'Custom Amount (₦)',
                                prefixIcon: Icons.edit_rounded,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                onChanged: (_) =>
                                    setState(() => _selectedAmount = null),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        GradientButton(
                          label: 'Buy Airtime',
                          onPressed: _buyAirtime,
                          isLoading: _loading,
                          icon: Icons.phone_android_rounded,
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
