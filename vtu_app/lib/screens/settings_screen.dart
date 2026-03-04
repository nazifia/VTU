import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/glass_card.dart';
import '../config/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final theme = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
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
                    // Theme section
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(context, 'Appearance',
                              Icons.palette_rounded),
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
                    // Security section
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              context, 'Security', Icons.security_rounded),
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
                            'Change PIN',
                            'Update your security PIN',
                            () {},
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Account section
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionHeader(
                              context, 'Account', Icons.manage_accounts_rounded),
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
                              applicationName: 'VTU App',
                              applicationVersion: '1.0.0',
                              applicationLegalese: '© 2025 VTU App',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Logout
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
              Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: Theme.of(ctx).textTheme.bodySmall),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
        ),
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
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style: Theme.of(ctx).textTheme.bodySmall),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.4)),
        ],
      ),
    );
  }

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
