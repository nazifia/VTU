import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_button.dart';
import '../widgets/custom_text_field.dart';
import '../config/theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim =
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    // register() creates the user AND generates+returns the OTP in one call
    final devOtp = await auth.register(
      phone: _phoneCtrl.text.trim(),
      pin: _pinCtrl.text.trim(),
      firstName: _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
    );
    if (!mounted) return;

    if (devOtp != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OtpScreen(
            phone: _phoneCtrl.text.trim(),
            firstName: _firstNameCtrl.text.trim(),
            lastName: _lastNameCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            pin: _pinCtrl.text.trim(),
            devOtp: devOtp,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? 'Registration failed'),
          backgroundColor: AppTheme.errorRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String? _validatePhone(String? v) {
    if (v == null || v.isEmpty) return 'Phone number is required';
    if (!RegExp(r'^[0-9]{10,11}$').hasMatch(v)) {
      return 'Enter a valid Nigerian phone number (10-11 digits)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Back + header
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_rounded),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              'Create Account',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 12),
                        child: Text(
                          'Join thousands using VTU Wallet',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Name row
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              controller: _firstNameCtrl,
                              label: 'First Name',
                              prefixIcon: Icons.person_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              controller: _lastNameCtrl,
                              label: 'Last Name',
                              prefixIcon: Icons.person_outline_rounded,
                              validator: (v) =>
                                  v!.isEmpty ? 'Required' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _phoneCtrl,
                        label: 'Phone Number',
                        hint: '08012345678',
                        prefixIcon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(11),
                        ],
                        validator: _validatePhone,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _emailCtrl,
                        label: 'Email (optional)',
                        prefixIcon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _pinCtrl,
                        label: 'Create Password / PIN',
                        hint: 'Min. 4 characters (letters & numbers)',
                        prefixIcon: Icons.lock_rounded,
                        obscureText: _obscurePin,
                        keyboardType: TextInputType.visiblePassword,
                        validator: (v) {
                          if (v!.isEmpty) return 'Password is required';
                          if (v.length < 4) return 'Minimum 4 characters';
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePin
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () =>
                              setState(() => _obscurePin = !_obscurePin),
                        ),
                      ),
                      const SizedBox(height: 14),
                      CustomTextField(
                        controller: _confirmPinCtrl,
                        label: 'Confirm Password / PIN',
                        hint: 'Re-enter your password',
                        prefixIcon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        keyboardType: TextInputType.visiblePassword,
                        textInputAction: TextInputAction.done,
                        validator: (v) {
                          if (v!.isEmpty) return 'Please confirm password';
                          if (v != _pinCtrl.text) return 'Passwords do not match';
                          return null;
                        },
                        suffixIcon: IconButton(
                          icon: Icon(_obscureConfirm
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded),
                          onPressed: () =>
                              setState(() => _obscureConfirm = !_obscureConfirm),
                        ),
                      ),
                      const SizedBox(height: 28),
                      GradientButton(
                        label: 'Continue',
                        onPressed: _register,
                        isLoading: auth.isLoading,
                        icon: Icons.arrow_forward_rounded,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text('Already have an account? ',
                              style: Theme.of(context).textTheme.bodyMedium),
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Text(
                              'Sign In',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── OTP Screen ─────────────────────────────────────────────────────────────

class OtpScreen extends StatefulWidget {
  final String phone;
  final String firstName;
  final String lastName;
  final String email;
  final String pin;
  /// OTP code returned by the server (shown in a dev banner so you don't need SMS).
  final String? devOtp;

  const OtpScreen({
    super.key,
    required this.phone,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.pin,
    this.devOtp,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _loading = false;
  int _resendCountdown = 60;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _canResend = false;
    _resendCountdown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCountdown--);
      if (_resendCountdown <= 0) {
        if (mounted) setState(() => _canResend = true);
        return false;
      }
      return true;
    });
  }

  String get _otp =>
      _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit OTP')),
      );
      return;
    }
    setState(() => _loading = true);
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyOtp(
      phone: widget.phone,
      otp: _otp,
    );
    if (mounted) {
      setState(() => _loading = false);
      if (success) {
        // OTP verified → user is now authenticated; navigate to the dashboard
        // and wipe the back-stack so Back can't return to register/OTP screens.
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/home',
          (_) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(auth.errorMessage ?? 'Invalid OTP'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _resend() async {
    if (!_canResend) return;
    final auth = context.read<AuthProvider>();
    await auth.sendOtp(widget.phone);
    if (mounted) {
      _startCountdown();
      for (final c in _controllers) c.clear();
      _focusNodes.first.requestFocus();
      if (widget.devOtp != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new OTP has been generated — check the dev banner'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final masked = widget.phone.replaceRange(4, widget.phone.length - 2, '****');

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient:
              isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text('Verify OTP',
                        style: Theme.of(context).textTheme.headlineMedium),
                  ],
                ),
                const SizedBox(height: 24),
                // Icon
                Center(
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.sms_rounded,
                        color: AppTheme.primaryIndigo, size: 40),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Code sent to',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  masked,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 20),
                // ── Dev OTP banner (remove in production) ──
                if (widget.devOtp != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.developer_mode_rounded,
                            color: Colors.amber, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'DEV — Your OTP is: ${widget.devOtp}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.amber,
                              fontSize: 15,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                if (widget.devOtp != null) const SizedBox(height: 16),
                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(6, (i) {
                    return SizedBox(
                      width: 48,
                      height: 56,
                      child: TextField(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 1,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                        decoration: InputDecoration(
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                        ),
                        onChanged: (v) {
                          if (v.isNotEmpty && i < 5) {
                            _focusNodes[i + 1].requestFocus();
                          }
                          if (v.isEmpty && i > 0) {
                            _focusNodes[i - 1].requestFocus();
                          }
                          if (_otp.length == 6) _verify();
                        },
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),
                GradientButton(
                  label: 'Verify',
                  onPressed: _verify,
                  isLoading: _loading,
                  icon: Icons.check_rounded,
                ),
                const SizedBox(height: 20),
                // Resend
                Center(
                  child: _canResend
                      ? GestureDetector(
                          onTap: _resend,
                          child: Text(
                            'Resend OTP',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          'Resend in ${_resendCountdown}s',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.5),
                              ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
