import 'package:flutter/material.dart';
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
