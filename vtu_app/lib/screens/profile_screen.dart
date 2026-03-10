import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_text_field.dart';
import '../widgets/glass_card.dart';
import '../config/theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _emailCtrl;
  bool _editing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _firstNameCtrl = TextEditingController(text: user?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: user?.lastName ?? '');
    _emailCtrl = TextEditingController(text: user?.email ?? '');
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    await context.read<AuthProvider>().updateProfile(
          firstName: _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
        );
    if (mounted) {
      setState(() {
        _saving = false;
        _editing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile updated!'),
          backgroundColor: AppTheme.secondaryEmerald,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: const Text('Profile'),
                backgroundColor: Colors.transparent,
                pinned: false,
                actions: [
                  IconButton(
                    icon: Icon(_editing ? Icons.close_rounded : Icons.edit_rounded),
                    onPressed: () => setState(() {
                      _editing = !_editing;
                      if (!_editing) {
                        _firstNameCtrl.text = user?.firstName ?? '';
                        _lastNameCtrl.text = user?.lastName ?? '';
                        _emailCtrl.text = user?.email ?? '';
                      }
                    }),
                  ),
                ],
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: [
                      // Avatar
                      GestureDetector(
                        onTap: _editing ? () {} : null,
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: AppTheme.primaryIndigo.withValues(alpha: 0.15),
                              child: Text(
                                user != null
                                    ? user.firstName[0].toUpperCase()
                                    : 'U',
                                style: const TextStyle(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryIndigo,
                                ),
                              ),
                            ),
                            if (_editing)
                              Positioned(
                                bottom: 4,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.primaryIndigo,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.camera_alt_rounded,
                                      color: Colors.white, size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.fullName ?? 'User',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user?.phone ?? '',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                      const SizedBox(height: 28),
                      // Info card
                      GlassCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text('Personal Information',
                                  style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 20),
                              CustomTextField(
                                controller: _firstNameCtrl,
                                label: 'First Name',
                                prefixIcon: Icons.person_rounded,
                                readOnly: !_editing,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _lastNameCtrl,
                                label: 'Last Name',
                                prefixIcon: Icons.person_outline_rounded,
                                readOnly: !_editing,
                                validator: (v) => v!.isEmpty ? 'Required' : null,
                              ),
                              const SizedBox(height: 14),
                              CustomTextField(
                                controller: _emailCtrl,
                                label: 'Email',
                                prefixIcon: Icons.email_rounded,
                                keyboardType: TextInputType.emailAddress,
                                readOnly: !_editing,
                              ),
                              if (_editing) ...[
                                const SizedBox(height: 20),
                                GradientButton(
                                  label: 'Save Changes',
                                  onPressed: _save,
                                  isLoading: _saving,
                                  icon: Icons.check_rounded,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // KYC / Identity Verification
                      _KycCard(auth: auth),
                      const SizedBox(height: 16),
                      // Biometric settings
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Security',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                const Icon(Icons.fingerprint_rounded,
                                    color: AppTheme.primaryIndigo),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Biometric Login',
                                          style: TextStyle(fontWeight: FontWeight.w500)),
                                      Text('Use fingerprint or face ID',
                                          style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: auth.isBiometricEnabled,
                                  onChanged: auth.setBiometricEnabled,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
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

// ── KYC Card ─────────────────────────────────────────────────────────────────

class _KycCard extends StatelessWidget {
  final AuthProvider auth;
  const _KycCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final user = auth.user;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Identity Verification (KYC)',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              if (user?.bvnVerified == true && user?.ninVerified == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryEmerald.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Fully Verified',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.secondaryEmerald)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Link your BVN and NIN to unlock higher limits and full account access.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          _KycRow(
            label: 'BVN',
            subtitle: 'Bank Verification Number',
            linked: user?.bvnLinked ?? false,
            verified: user?.bvnVerified ?? false,
            onTap: () => _showKycSheet(context, 'bvn'),
          ),
          const Divider(height: 24),
          _KycRow(
            label: 'NIN',
            subtitle: 'National ID Number',
            linked: user?.ninLinked ?? false,
            verified: user?.ninVerified ?? false,
            onTap: () => _showKycSheet(context, 'nin'),
          ),
        ],
      ),
    );
  }

  void _showKycSheet(BuildContext context, String type) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _KycSheet(auth: auth, type: type),
    );
  }
}

class _KycRow extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool linked;
  final bool verified;
  final VoidCallback onTap;

  const _KycRow({
    required this.label,
    required this.subtitle,
    required this.linked,
    required this.verified,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor;
    final IconData icon;
    final String statusText;
    final Color statusColor;

    if (verified) {
      iconColor = AppTheme.secondaryEmerald;
      icon = Icons.verified_rounded;
      statusText = 'Verified';
      statusColor = AppTheme.secondaryEmerald;
    } else if (linked) {
      iconColor = AppTheme.warningAmber;
      icon = Icons.schedule_rounded;
      statusText = 'Pending';
      statusColor = AppTheme.warningAmber;
    } else {
      iconColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3);
      icon = Icons.link_off_rounded;
      statusText = 'Not Linked';
      statusColor = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (!verified)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryIndigo,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
            ),
            child: Text(linked ? 'Re-link' : 'Link',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(statusText,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: statusColor)),
          ),
      ],
    );
  }
}

// ── KYC submission sheet ──────────────────────────────────────────────────────

class _KycSheet extends StatefulWidget {
  final AuthProvider auth;
  final String type; // 'bvn' or 'nin'

  const _KycSheet({required this.auth, required this.type});

  @override
  State<_KycSheet> createState() => _KycSheetState();
}

class _KycSheetState extends State<_KycSheet> {
  final _ctrl    = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading  = false;
  String? _error;
  String? _successStatus;

  bool get _isBvn => widget.type == 'bvn';
  String get _label => _isBvn ? 'BVN' : 'NIN';
  String get _hint  => _isBvn
      ? 'Enter your 11-digit BVN'
      : 'Enter your 11-digit NIN';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; _successStatus = null; });

    final err = await widget.auth.submitKyc(
      bvn: _isBvn ? _ctrl.text.trim() : null,
      nin: _isBvn ? null : _ctrl.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
    } else {
      final user = widget.auth.user;
      final isVerified = _isBvn ? (user?.bvnVerified ?? false) : (user?.ninVerified ?? false);
      setState(() => _successStatus = isVerified ? 'verified' : 'pending');
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
        child: _successStatus != null
            ? _SuccessView(
                status: _successStatus!,
                label: _label,
                onDone: () => Navigator.pop(context),
              )
            : Form(
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
                    Text('Link Your $_label',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      _isBvn
                          ? 'Your BVN is a unique 11-digit number assigned by your bank. Dial *565*0# to retrieve it.'
                          : 'Your NIN is an 11-digit number on your National ID slip or card.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      controller: _ctrl,
                      keyboardType: TextInputType.number,
                      maxLength: 11,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: '$_label Number',
                        hintText: _hint,
                        prefixIcon: const Icon(Icons.badge_rounded),
                        counterText: '',
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter your $_label';
                        if (v.length != 11) return '$_label must be exactly 11 digits';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryIndigo.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 16, color: AppTheme.primaryIndigo),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Your $_label is encrypted and stored securely. '
                              'It will only be used for identity verification.',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: AppTheme.primaryIndigo),
                            ),
                          ),
                        ],
                      ),
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
                            const Icon(Icons.error_outline,
                                color: AppTheme.errorRed, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_error!,
                                  style: const TextStyle(
                                      color: AppTheme.errorRed, fontSize: 13)),
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
                            : Text('Submit $_label',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600, fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String status;
  final String label;
  final VoidCallback onDone;

  const _SuccessView({
    required this.status,
    required this.label,
    required this.onDone,
  });

  @override
  Widget build(BuildContext context) {
    final verified = status == 'verified';
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Icon(
          verified ? Icons.verified_rounded : Icons.schedule_rounded,
          size: 64,
          color: verified ? AppTheme.secondaryEmerald : AppTheme.warningAmber,
        ),
        const SizedBox(height: 16),
        Text(
          verified ? '$label Verified!' : '$label Submitted',
          style: Theme.of(context)
              .textTheme
              .titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          verified
              ? 'Your $label has been successfully verified.'
              : 'Your $label is under review. Verification usually takes a few minutes.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  verified ? AppTheme.secondaryEmerald : AppTheme.primaryIndigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Done',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
