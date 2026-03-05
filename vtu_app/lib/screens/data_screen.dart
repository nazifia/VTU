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

  static const _providers = [
    {'name': 'MTN', 'color': Color(0xFFFFCC00)},
    {'name': 'Glo', 'color': Color(0xFF00A651)},
    {'name': 'Airtel', 'color': Color(0xFFD2222D)},
    {'name': '9mobile', 'color': Color(0xFF006633)},
  ];

  static const _bundles = <_DataBundle>[
    _DataBundle('500MB', 100, '1 Day', 'mtn_500mb_1day'),
    _DataBundle('1GB', 200, '7 Days', 'mtn_1gb_7days'),
    _DataBundle('2GB', 500, '30 Days', 'mtn_2gb_30days'),
    _DataBundle('5GB', 1000, '30 Days', 'mtn_5gb_30days'),
    _DataBundle('10GB', 2000, '30 Days', 'mtn_10gb_30days'),
    _DataBundle('20GB', 3500, '30 Days', 'mtn_20gb_30days'),
  ];

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
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

    setState(() => _loading = true);
    final success = await context.read<AuthProvider>().purchaseData(
          phone: _phoneCtrl.text.trim(),
          provider: _selectedProvider!,
          planId: _selectedBundle!.planId,
          amount: _selectedBundle!.price.toDouble(),
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
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_rounded,
                  color: Color(0xFF8B5CF6), size: 40),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Buy Data'),
        backgroundColor:
            isDark ? AppTheme.darkBgGradient.colors.first : AppTheme.lightBgGradient.colors.first,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Form(
            key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Provider selector
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
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Phone Number',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
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
                                        if (v.length < 11) {
                                          return 'Enter valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filled(
                                    tooltip: 'Pick from contacts',
                                    style: IconButton.styleFrom(
                                      backgroundColor: const Color(0xFF8B5CF6)
                                          .withValues(alpha: 0.12),
                                      foregroundColor: const Color(0xFF8B5CF6),
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
                        // Bundle grid
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Select Bundle',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 16),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 10,
                                  mainAxisSpacing: 10,
                                  childAspectRatio: 1.05,
                                ),
                                itemCount: _bundles.length,
                                itemBuilder: (_, i) {
                                  final b = _bundles[i];
                                  final isSelected = _selectedBundle == b;
                                  return GestureDetector(
                                    onTap: () =>
                                        setState(() => _selectedBundle = b),
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      decoration: BoxDecoration(
                                        gradient: isSelected
                                            ? LinearGradient(
                                                colors: [
                                                  dataColor,
                                                  dataColor.withValues(
                                                      alpha: 0.7)
                                                ],
                                              )
                                            : null,
                                        color: isSelected
                                            ? null
                                            : Theme.of(context)
                                                .colorScheme
                                                .surface,
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isSelected
                                              ? Colors.transparent
                                              : Theme.of(context)
                                                  .dividerColor
                                                  .withValues(alpha: 0.3),
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            b.size,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 16,
                                              color: isSelected
                                                  ? Colors.white
                                                  : dataColor,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            b.price.formatCurrency,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? Colors.white70
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            b.validity,
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
                                },
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
            );
  }
}

class _DataBundle {
  final String size;
  final int price;
  final String validity;
  final String planId;

  const _DataBundle(this.size, this.price, this.validity, this.planId);
}
