import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glass_card.dart';
import '../config/theme.dart';
import '../utils/currency_formatter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.user;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              const SliverAppBar(
                title: Text('Settings'),
                backgroundColor: Colors.transparent,
                pinned: false,
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Appearance
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Appearance', Icons.palette_rounded),
                          const SizedBox(height: 16),
                          _switchTile(
                            context,
                            Icons.dark_mode_rounded,
                            'Dark Mode',
                            'Switch between light and dark theme',
                            theme.isDark,
                            (_) => theme.toggle(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Security
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Security', Icons.security_rounded),
                          const SizedBox(height: 16),
                          _switchTile(
                            context,
                            Icons.fingerprint_rounded,
                            'Biometric Login',
                            'Use fingerprint or face ID to login',
                            auth.isBiometricEnabled,
                            (v) => auth.setBiometricEnabled(v),
                          ),
                          const Divider(height: 24),
                          _actionTile(
                            context,
                            Icons.lock_reset_rounded,
                            user?.hasTransactionPin == true
                                ? 'Change Transaction PIN'
                                : 'Set Transaction PIN',
                            user?.hasTransactionPin == true
                                ? 'Update your 4–6 digit transaction PIN'
                                : 'Create a PIN to authorise transactions',
                            () => _showChangePinSheet(context, auth),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Wallet Limits
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Spending Limits', Icons.speed_rounded),
                          const SizedBox(height: 4),
                          Text(
                            'Max self-set: ₦200,000/day · ₦2,000,000/month',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _limitRow(
                            context,
                            Icons.today_rounded,
                            'Daily Limit',
                            (user?.dailyLimit ?? 50000).formatCurrency,
                          ),
                          const SizedBox(height: 12),
                          _limitRow(
                            context,
                            Icons.calendar_month_rounded,
                            'Monthly Limit',
                            (user?.monthlyLimit ?? 500000).formatCurrency,
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.edit_rounded, size: 18),
                              label: const Text('Update Limits'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primaryIndigo,
                                side: const BorderSide(color: AppTheme.primaryIndigo),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              onPressed: () => _showLimitsSheet(context, auth),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Server Configuration
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Network', Icons.cloud_rounded),
                          const SizedBox(height: 4),
                          Text(
                            'Configure backend server for mobile internet',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 16),
                          _actionTile(
                            context,
                            Icons.dns_rounded,
                            'Server URL',
                            auth.serverUrl,
                            () => _showServerUrlSheet(context, auth),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Account
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Account', Icons.manage_accounts_rounded),
                          const SizedBox(height: 16),
                          _actionTile(
                            context,
                            Icons.person_rounded,
                            'Edit Profile',
                            'Update your personal information',
                            () => Navigator.pushNamed(context, '/profile'),
                          ),
                          const Divider(height: 24),
                          _actionTile(
                            context,
                            Icons.help_outline_rounded,
                            'Help & Support',
                            'Get help with your account',
                            () {},
                          ),
                          const Divider(height: 24),
                          _actionTile(
                            context,
                            Icons.info_outline_rounded,
                            'About',
                            'App version 1.0.0',
                            () => showAboutDialog(
                              context: context,
                              applicationName: 'Npay',
                              applicationVersion: '1.0.0',
                              applicationLegalese: '© 2025 Npay',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Sign out
                    GlassCard(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _confirmLogout(context, auth),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.errorRed.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.logout_rounded,
                                  color: AppTheme.errorRed, size: 22),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Text(
                                'Sign Out',
                                style: TextStyle(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.errorRed),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _sectionHeader(BuildContext ctx, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryIndigo, size: 20),
        const SizedBox(width: 8),
        Text(title, style: Theme.of(ctx).textTheme.titleMedium),
      ],
    );
  }

  Widget _switchTile(BuildContext ctx, IconData icon, String title,
      String subtitle, bool value, void Function(bool) onChanged) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.primaryIndigo, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    );
  }

  Widget _actionTile(BuildContext ctx, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryIndigo.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primaryIndigo, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle, style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

  Widget _limitRow(BuildContext ctx, IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.secondaryEmerald.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppTheme.secondaryEmerald, size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(label,
              style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        Text(value,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.secondaryEmerald)),
      ],
    );
  }

  // ── Server URL bottom sheet ───────────────────────────────────────────────

  void _showServerUrlSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServerUrlSheet(auth: auth),
    );
  }

  // ── Change PIN bottom sheet ───────────────────────────────────────────────

  void _showChangePinSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChangePinSheet(auth: auth),
    );
  }

  // ── Wallet limits bottom sheet ────────────────────────────────────────────

  void _showLimitsSheet(BuildContext context, AuthProvider auth) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletLimitsSheet(auth: auth),
    );
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  Future<void> _confirmLogout(BuildContext ctx, AuthProvider auth) async {
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await auth.logout();
  }
}

// ── Change PIN sheet ──────────────────────────────────────────────────────────

class _ChangePinSheet extends StatefulWidget {
  final AuthProvider auth;
  const _ChangePinSheet({required this.auth});

  @override
  State<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends State<_ChangePinSheet> {
  final _currentCtrl  = TextEditingController();
  final _newCtrl      = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _formKey      = GlobalKey<FormState>();
  bool _loading       = false;
  String? _error;

  bool get _hasPin => widget.auth.user?.hasTransactionPin ?? false;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final err = await widget.auth.setTransactionPin(
      currentPin: _hasPin ? _currentCtrl.text : null,
      newPin: _newCtrl.text,
      confirmPin: _confirmCtrl.text,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction PIN updated successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.secondaryEmerald,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _hasPin ? 'Change Transaction PIN' : 'Set Transaction PIN',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 4),
              Text(
                'Your PIN is used to authorise payments and transfers.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),

              if (_hasPin) ...[
                _PinField(
                  controller: _currentCtrl,
                  label: 'Current PIN',
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your current PIN';
                    if (v.length < 4) return 'PIN must be at least 4 digits';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              _PinField(
                controller: _newCtrl,
                label: 'New PIN',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter a new PIN';
                  if (v.length < 4) return 'PIN must be at least 4 digits';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _PinField(
                controller: _confirmCtrl,
                label: 'Confirm New PIN',
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your new PIN';
                  if (v != _newCtrl.text) return 'PINs do not match';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(_hasPin ? 'Update PIN' : 'Set PIN',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;

  const _PinField({
    required this.controller,
    required this.label,
    this.validator,
  });

  @override
  State<_PinField> createState() => _PinFieldState();
}

class _PinFieldState extends State<_PinField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      keyboardType: TextInputType.number,
      maxLength: 6,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: widget.label,
        counterText: '',
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
      validator: widget.validator,
    );
  }
}

// ── Wallet limits sheet ───────────────────────────────────────────────────────

class _WalletLimitsSheet extends StatefulWidget {
  final AuthProvider auth;
  const _WalletLimitsSheet({required this.auth});

  @override
  State<_WalletLimitsSheet> createState() => _WalletLimitsSheetState();
}

class _WalletLimitsSheetState extends State<_WalletLimitsSheet> {
  final _dailyCtrl   = TextEditingController();
  final _monthlyCtrl = TextEditingController();
  final _formKey     = GlobalKey<FormState>();
  bool _loading      = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.auth.user;
    _dailyCtrl.text   = (user?.dailyLimit   ?? 50000).toStringAsFixed(0);
    _monthlyCtrl.text = (user?.monthlyLimit ?? 500000).toStringAsFixed(0);
  }

  @override
  void dispose() {
    _dailyCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    final daily   = double.tryParse(_dailyCtrl.text);
    final monthly = double.tryParse(_monthlyCtrl.text);

    final err = await widget.auth.updateWalletLimits(
      dailyLimit: daily,
      monthlyLimit: monthly,
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Spending limits updated successfully.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.secondaryEmerald,
        ),
      );
    }
  }

  String? _validateAmount(String? v, String field, double max) {
    if (v == null || v.isEmpty) return 'Enter $field';
    final n = double.tryParse(v);
    if (n == null || n <= 0) return 'Enter a valid amount';
    if (n > max) return 'Max allowed: ₦${max.toStringAsFixed(0)}';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Update Spending Limits',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text('Maximum: ₦200,000/day · ₦2,000,000/month',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 24),

              TextFormField(
                controller: _dailyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Daily Limit (₦)',
                  prefixIcon: const Icon(Icons.today_rounded),
                  helperText: 'Current: ${(widget.auth.user?.dailyLimit ?? 50000).formatCurrency}',
                ),
                validator: (v) => _validateAmount(v, 'daily limit', 200000),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _monthlyCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Monthly Limit (₦)',
                  prefixIcon: const Icon(Icons.calendar_month_rounded),
                  helperText: 'Current: ${(widget.auth.user?.monthlyLimit ?? 500000).formatCurrency}',
                ),
                validator: (v) {
                  final baseErr = _validateAmount(v, 'monthly limit', 2000000);
                  if (baseErr != null) return baseErr;
                  final daily   = double.tryParse(_dailyCtrl.text) ?? 0;
                  final monthly = double.tryParse(v!) ?? 0;
                  if (monthly < daily) return 'Monthly limit must be ≥ daily limit';
                  return null;
                },
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save Limits',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Server URL sheet ──────────────────────────────────────────────────────────

class _ServerUrlSheet extends StatefulWidget {
  final AuthProvider auth;
  const _ServerUrlSheet({required this.auth});

  @override
  State<_ServerUrlSheet> createState() => _ServerUrlSheetState();
}

class _ServerUrlSheetState extends State<_ServerUrlSheet> {
  late final TextEditingController _ctrl;
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.auth.serverUrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await widget.auth.updateServerUrl(_ctrl.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server URL updated. Restart the app to apply.'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.secondaryEmerald,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('Server URL', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Set the backend URL for mobile internet access.\nExample: http://your-server-ip:8000/api/v1',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _ctrl,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  prefixIcon: Icon(Icons.link_rounded),
                  hintText: 'http://192.168.x.x:8000/api/v1',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'URL is required';
                  final uri = Uri.tryParse(v.trim());
                  if (uri == null || !uri.hasScheme) return 'Enter a valid URL';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryIndigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
