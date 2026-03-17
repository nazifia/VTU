import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'app_shell.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  // Logo: scale + fade
  late final AnimationController _logoCtrl;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;

  // App name: slide up + fade
  late final AnimationController _titleCtrl;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;

  // Tagline: fade
  late final AnimationController _taglineCtrl;
  late final Animation<double> _taglineFade;

  // Progress dots: fade
  late final AnimationController _dotsCtrl;
  late final Animation<double> _dotsFade;

  bool _authDone = false;
  bool _minTimeDone = false;
  bool _navigated = false;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();

    // --- Logo ---
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _logoScale = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
            parent: _logoCtrl,
            curve: const Interval(0.0, 0.5, curve: Curves.easeIn)));

    // --- Title (starts 300 ms after logo) ---
    _titleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _titleSlide = Tween<Offset>(
            begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
            CurvedAnimation(parent: _titleCtrl, curve: Curves.easeOutCubic));
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _titleCtrl, curve: Curves.easeIn));

    // --- Tagline (starts 200 ms after title) ---
    _taglineCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeIn));

    // --- Loading dots (starts 200 ms after tagline) ---
    _dotsCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _dotsCtrl, curve: Curves.easeIn));

    _runAnimations();
    _runAuth();
    _startMinTimer();
  }

  Future<void> _runAnimations() async {
    if (_disposed) return;
    await _logoCtrl.forward();
    if (_disposed) return;
    await Future.delayed(const Duration(milliseconds: 100));
    if (_disposed) return;
    await _titleCtrl.forward();
    if (_disposed) return;
    await Future.delayed(const Duration(milliseconds: 150));
    if (_disposed) return;
    await _taglineCtrl.forward();
    if (_disposed) return;
    await Future.delayed(const Duration(milliseconds: 150));
    if (_disposed) return;
    await _dotsCtrl.forward();
  }

  Future<void> _runAuth() async {
    await context.read<AuthProvider>().init();
    _authDone = true;
    _maybeNavigate();
  }

  void _startMinTimer() {
    Timer(const Duration(milliseconds: 2500), () {
      _minTimeDone = true;
      _maybeNavigate();
    });
  }

  void _maybeNavigate() {
    if (!_authDone || !_minTimeDone || _navigated) return;
    _navigated = true;
    if (!mounted) return;

    final isAuth = context.read<AuthProvider>().isAuthenticated;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (ctx, animation, secondary) =>
            isAuth ? const AppShell() : const LoginScreen(),
        transitionsBuilder: (ctx, animation, secondary, child) => FadeTransition(
          opacity: animation,
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _logoCtrl.dispose();
    _titleCtrl.dispose();
    _taglineCtrl.dispose();
    _dotsCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Stack(
          children: [
            // Decorative background circles
            Positioned(
              top: -80,
              right: -60,
              child: _GlowCircle(
                size: 260,
                color: AppTheme.primaryIndigo.withValues(alpha: isDark ? 0.15 : 0.08),
              ),
            ),
            Positioned(
              bottom: -100,
              left: -70,
              child: _GlowCircle(
                size: 300,
                color: AppTheme.secondaryEmerald.withValues(alpha: isDark ? 0.10 : 0.06),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  ScaleTransition(
                    scale: _logoScale,
                    child: FadeTransition(
                      opacity: _logoFade,
                      child: Container(
                        width: 108,
                        height: 108,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primaryIndigo.withValues(alpha: 0.45),
                              blurRadius: 40,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet_rounded,
                          color: Colors.white,
                          size: 54,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // App name
                  SlideTransition(
                    position: _titleSlide,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: Text(
                        'Npay',
                        style: Theme.of(context)
                            .textTheme
                            .displayMedium
                            ?.copyWith(
                              color: AppTheme.primaryIndigo,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tagline
                  FadeTransition(
                    opacity: _taglineFade,
                    child: Text(
                      'Your Nigerian FinTech Wallet',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.55),
                            letterSpacing: 0.3,
                          ),
                    ),
                  ),

                  const SizedBox(height: 64),

                  // Loading dots
                  FadeTransition(
                    opacity: _dotsFade,
                    child: const _PulsingDots(),
                  ),
                ],
              ),
            ),

            // Version tag at bottom
            Positioned(
              bottom: 32,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _taglineFade,
                child: Text(
                  'v1.0.0',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Decorative glow circle ──────────────────────────────────────────────────
class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;
  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }
}

// ── Animated pulsing dots ───────────────────────────────────────────────────
class _PulsingDots extends StatefulWidget {
  const _PulsingDots();

  @override
  State<_PulsingDots> createState() => _PulsingDotsState();
}

class _PulsingDotsState extends State<_PulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final start = i * 0.2;
        final end = start + 0.4;
        final anim = Tween<double>(begin: 0.3, end: 1.0).animate(
          CurvedAnimation(
            parent: _ctrl,
            curve: Interval(start, end < 1.0 ? end : 1.0,
                curve: Curves.easeInOut),
          ),
        );
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: AnimatedBuilder(
            animation: anim,
            builder: (ctx, child) => Opacity(
              opacity: anim.value,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppTheme.primaryIndigo,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
