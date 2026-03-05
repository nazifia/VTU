import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../config/theme.dart';
import '../utils/currency_formatter.dart';

class BillsScreen extends StatefulWidget {
  const BillsScreen({super.key});

  @override
  State<BillsScreen> createState() => _BillsScreenState();
}

class _BillsScreenState extends State<BillsScreen> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const amber = Color(0xFFF59E0B);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pay Bills'),
          backgroundColor: isDark
              ? AppTheme.darkBgGradient.colors.first
              : AppTheme.lightBgGradient.colors.first,
          bottom: const TabBar(
            labelColor: amber,
            indicatorColor: amber,
            tabs: [
              Tab(icon: Icon(Icons.bolt_rounded), text: 'Electricity'),
              Tab(icon: Icon(Icons.tv_rounded), text: 'Cable TV'),
              Tab(icon: Icon(Icons.water_drop_rounded), text: 'Water'),
            ],
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient:
                isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
          ),
          child: const TabBarView(
            children: [
              _ElectricityTab(),
              _CableTvTab(),
              _WaterTab(),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Electricity Tab ─────────────────────────────────────────────────────────

class _ElectricityTab extends StatefulWidget {
  const _ElectricityTab();

  @override
  State<_ElectricityTab> createState() => _ElectricityTabState();
}

class _ElectricityTabState extends State<_ElectricityTab> {
  final _formKey = GlobalKey<FormState>();
  final _meterCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedDisco;
  String? _meterName;
  bool _verifying = false;
  bool _loading = false;

  static const _discos = [
    'Abuja Electricity (AEDC)',
    'Eko Electricity (EKEDC)',
    'Ikeja Electricity (IKEDC)',
    'Ibadan Electricity (IBEDC)',
    'Enugu Electricity (EEDC)',
    'Port Harcourt Electricity (PHEDC)',
    'Kano Electricity (KEDCO)',
    'Kaduna Electricity (KAEDCO)',
    'Jos Electricity (JED)',
    'Benin Electricity (BEDC)',
    'Yola Electricity (YEDC)',
  ];

  @override
  void dispose() {
    _meterCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyMeter() async {
    if (_meterCtrl.text.length < 11 || _selectedDisco == null) return;
    setState(() {
      _verifying = true;
      _meterName = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _verifying = false;
        _meterName = 'JOHN DOE';
      });
    }
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_meterName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your meter number first')),
      );
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.bankTransfer(
      accountNumber: _meterCtrl.text,
      bankCode: 'ELEC',
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      narration: 'Electricity: $_selectedDisco',
    );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        _showSuccess();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Payment failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        icon: Icons.bolt_rounded,
        color: const Color(0xFFF59E0B),
        title: 'Payment Successful!',
        subtitle:
            '${(double.tryParse(_amountCtrl.text) ?? 0).formatCurrency} electricity credit sent to meter ${_meterCtrl.text}',
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Electricity Details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownSearch<String>(
                    items: (filter, _) => _discos
                        .where((d) => d
                            .toLowerCase()
                            .contains(filter.toLowerCase()))
                        .toList(),
                    selectedItem: _selectedDisco,
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Distribution Company (DISCO)',
                        prefixIcon: const Icon(Icons.business_rounded),
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
                          hintText: 'Search DISCO...',
                          prefixIcon: const Icon(Icons.search_rounded),
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
                      _selectedDisco = v;
                      _meterName = null;
                    }),
                    validator: (v) => v == null ? 'Select a DISCO' : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _meterCtrl,
                    label: 'Meter Number',
                    prefixIcon: Icons.electrical_services_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(13),
                    ],
                    onChanged: (v) {
                      if (v.length >= 11) _verifyMeter();
                    },
                    validator: (v) {
                      if (v!.isEmpty) return 'Meter number required';
                      if (v.length < 11) return 'Enter valid meter number';
                      return null;
                    },
                  ),
                  if (_verifying)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Verifying meter...'),
                      ]),
                    ),
                  if (_meterName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryEmerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.secondaryEmerald, size: 18),
                            const SizedBox(width: 8),
                            Text(_meterName!,
                                style: const TextStyle(
                                  color: AppTheme.secondaryEmerald,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _amountCtrl,
                    label: 'Amount (₦)',
                    prefixIcon: Icons.payments_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      if (double.parse(v) < 100) return 'Minimum is ${(100).formatCurrency}';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Pay Electricity Bill',
              onPressed: _pay,
              isLoading: _loading,
              icon: Icons.bolt_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cable TV Tab ─────────────────────────────────────────────────────────────

class _CableTvTab extends StatefulWidget {
  const _CableTvTab();

  @override
  State<_CableTvTab> createState() => _CableTvTabState();
}

class _CableTvTabState extends State<_CableTvTab> {
  final _formKey = GlobalKey<FormState>();
  final _smartcardCtrl = TextEditingController();
  String? _selectedProvider;
  String? _selectedPlan;
  String? _smartcardName;
  bool _verifying = false;
  bool _loading = false;

  static const _providers = ['DSTV', 'GOtv', 'Startimes'];
  static const _plans = <String, List<Map<String, dynamic>>>{
    'DSTV': [
      {'name': 'Padi', 'price': 2500},
      {'name': 'Yanga', 'price': 3500},
      {'name': 'Confam', 'price': 6200},
      {'name': 'Compact', 'price': 10500},
      {'name': 'Compact Plus', 'price': 16600},
      {'name': 'Premium', 'price': 24500},
    ],
    'GOtv': [
      {'name': 'Smallie', 'price': 900},
      {'name': 'Jinja', 'price': 1900},
      {'name': 'Jolli', 'price': 2800},
      {'name': 'Max', 'price': 4150},
      {'name': 'Supa', 'price': 6400},
    ],
    'Startimes': [
      {'name': 'Nova', 'price': 1200},
      {'name': 'Basic', 'price': 2000},
      {'name': 'Smart', 'price': 2600},
      {'name': 'Classic', 'price': 3000},
      {'name': 'Super', 'price': 5200},
    ],
  };

  @override
  void dispose() {
    _smartcardCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _currentPlans =>
      _plans[_selectedProvider] ?? [];

  Future<void> _verifySmart() async {
    if (_smartcardCtrl.text.length < 10 || _selectedProvider == null) return;
    setState(() {
      _verifying = true;
      _smartcardName = null;
    });
    await Future.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      setState(() {
        _verifying = false;
        _smartcardName = 'JOHN DOE';
      });
    }
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPlan == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a plan')),
      );
      return;
    }
    if (_smartcardName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please verify your smartcard number')),
      );
      return;
    }
    setState(() => _loading = true);
    final plan = _currentPlans.firstWhere((p) => p['name'] == _selectedPlan);
    final auth = context.read<AuthProvider>();
    final success = await auth.bankTransfer(
      accountNumber: _smartcardCtrl.text,
      bankCode: 'CABLE',
      amount: (plan['price'] as int).toDouble(),
      narration: '$_selectedProvider $_selectedPlan subscription',
    );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        _showSuccess(plan);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Payment failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showSuccess(Map<String, dynamic> plan) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SuccessSheet(
        icon: Icons.tv_rounded,
        color: AppTheme.primaryIndigo,
        title: 'Subscription Successful!',
        subtitle:
            '$_selectedProvider ${plan['name']} (${(plan['price'] as num).formatCurrency}) renewed for ${_smartcardCtrl.text}',
        onDone: () {
          Navigator.pop(context);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cable TV Details',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownSearch<String>(
                    items: (filter, _) => _providers
                        .where((p) => p
                            .toLowerCase()
                            .contains(filter.toLowerCase()))
                        .toList(),
                    selectedItem: _selectedProvider,
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Cable Provider',
                        prefixIcon: const Icon(Icons.tv_rounded),
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
                          prefixIcon: const Icon(Icons.search_rounded),
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
                      _selectedPlan = null;
                      _smartcardName = null;
                    }),
                    validator: (v) => v == null ? 'Select a provider' : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _smartcardCtrl,
                    label: 'Smartcard / IUC Number',
                    prefixIcon: Icons.credit_card_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: (v) {
                      if (v.length >= 10) _verifySmart();
                    },
                    validator: (v) {
                      if (v!.isEmpty) return 'Smartcard number required';
                      if (v.length < 10) return 'Enter valid smartcard number';
                      return null;
                    },
                  ),
                  if (_verifying)
                    const Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: Row(children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Verifying...'),
                      ]),
                    ),
                  if (_smartcardName != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color:
                              AppTheme.secondaryEmerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded,
                                color: AppTheme.secondaryEmerald, size: 18),
                            const SizedBox(width: 8),
                            Text(_smartcardName!,
                                style: const TextStyle(
                                  color: AppTheme.secondaryEmerald,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  if (_selectedProvider != null) ...[
                    const SizedBox(height: 14),
                    DropdownSearch<String>(
                      items: (filter, _) => _currentPlans
                          .map((p) => p['name'] as String)
                          .where((n) => n
                              .toLowerCase()
                              .contains(filter.toLowerCase()))
                          .toList(),
                      selectedItem: _selectedPlan,
                      decoratorProps: DropDownDecoratorProps(
                        decoration: InputDecoration(
                          labelText: 'Select Plan',
                          prefixIcon:
                              const Icon(Icons.featured_play_list_rounded),
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
                            hintText: 'Search plan...',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        itemBuilder: (ctx, name, isSelected, _) {
                          final plan = _currentPlans
                              .firstWhere((p) => p['name'] == name);
                          return ListTile(
                            title: Text(name),
                            trailing: Text(
                              (plan['price'] as num).formatCurrency,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primaryIndigo,
                              ),
                            ),
                          );
                        },
                        menuProps: MenuProps(
                          borderRadius: BorderRadius.circular(16),
                          elevation: 8,
                        ),
                      ),
                      onChanged: (v) => setState(() => _selectedPlan = v),
                      validator: (v) => v == null ? 'Select a plan' : null,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Pay Subscription',
              onPressed: _pay,
              isLoading: _loading,
              icon: Icons.tv_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Water Tab ─────────────────────────────────────────────────────────────────

class _WaterTab extends StatefulWidget {
  const _WaterTab();

  @override
  State<_WaterTab> createState() => _WaterTabState();
}

class _WaterTabState extends State<_WaterTab> {
  final _formKey = GlobalKey<FormState>();
  final _accountCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String? _selectedBoard;
  bool _loading = false;

  static const _boards = [
    'Lagos Water Corporation',
    'Abuja Water Board (AEPB)',
    'Rivers State Water Agency',
    'Kano State Water Board',
    'Oyo State Water Corporation',
  ];

  @override
  void dispose() {
    _accountCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.bankTransfer(
      accountNumber: _accountCtrl.text,
      bankCode: 'WATER',
      amount: double.tryParse(_amountCtrl.text) ?? 0,
      narration: 'Water bill: $_selectedBoard',
    );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (_) => _SuccessSheet(
            icon: Icons.water_drop_rounded,
            color: const Color(0xFF0EA5E9),
            title: 'Payment Successful!',
            subtitle:
                '${(double.tryParse(_amountCtrl.text) ?? 0).formatCurrency} water bill paid for account ${_accountCtrl.text}',
            onDone: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Payment failed'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Water Bill Payment',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  DropdownSearch<String>(
                    items: (filter, _) => _boards
                        .where((b) => b
                            .toLowerCase()
                            .contains(filter.toLowerCase()))
                        .toList(),
                    selectedItem: _selectedBoard,
                    decoratorProps: DropDownDecoratorProps(
                      decoration: InputDecoration(
                        labelText: 'Water Board',
                        prefixIcon: const Icon(Icons.water_drop_rounded),
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
                          hintText: 'Search water board...',
                          prefixIcon: const Icon(Icons.search_rounded),
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
                    onChanged: (v) => setState(() => _selectedBoard = v),
                    validator: (v) => v == null ? 'Select water board' : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _accountCtrl,
                    label: 'Account Number',
                    prefixIcon: Icons.numbers_rounded,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    validator: (v) =>
                        v!.isEmpty ? 'Account number required' : null,
                  ),
                  const SizedBox(height: 14),
                  CustomTextField(
                    controller: _amountCtrl,
                    label: 'Amount (₦)',
                    prefixIcon: Icons.payments_rounded,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    validator: (v) {
                      if (v!.isEmpty) return 'Enter amount';
                      if (double.tryParse(v) == null) return 'Invalid amount';
                      if (double.parse(v) < 100) return 'Minimum is ${(100).formatCurrency}';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            GradientButton(
              label: 'Pay Water Bill',
              onPressed: _pay,
              isLoading: _loading,
              icon: Icons.water_drop_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared Success Sheet ─────────────────────────────────────────────────────

class _SuccessSheet extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onDone;

  const _SuccessSheet({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 40),
          ),
          const SizedBox(height: 16),
          Text(title,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 20)),
          const SizedBox(height: 8),
          Text(subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          GradientButton(label: 'Done', onPressed: onDone),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
