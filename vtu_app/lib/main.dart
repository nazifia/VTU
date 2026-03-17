import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';
import 'services/storage_service.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/app_shell.dart';
import 'screens/register_screen.dart';
import 'screens/transfer_screen.dart';
import 'screens/airtime_screen.dart';
import 'screens/data_screen.dart';
import 'screens/bills_screen.dart';
import 'screens/transactions_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/fund_wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize services
  final storage = StorageService();
  final biometric = BiometricService();
  final ApiService api = ApiService(storage, baseUrl: await storage.getServerUrl());

  // Initialize providers
  final themeProvider = ThemeProvider(storage);
  await themeProvider.init();

  final authProvider = AuthProvider(api, storage, biometric);
  final configProvider = ConfigProvider();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: authProvider),
        ChangeNotifierProvider.value(value: configProvider),
      ],
      child: const NpayApp(),
    ),
  );
}

class NpayApp extends StatefulWidget {
  const NpayApp({super.key});

  @override
  State<NpayApp> createState() => _NpayAppState();
}

class _NpayAppState extends State<NpayApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  Timer? _authTimer;
  DateTime _lastInteraction = DateTime.now();

  @override
  void initState() {
    super.initState();
    _resetTimer();
  }

  void _resetTimer() {
    if (!mounted) return;
    
    // Throttle resetting the timer to at most once per second
    final now = DateTime.now();
    if (now.difference(_lastInteraction).inSeconds < 1 && _authTimer != null) {
      return;
    }
    _lastInteraction = now;

    _authTimer?.cancel();
    _authTimer = Timer(const Duration(minutes: 2), _logoutUser);
  }

  void _logoutUser() {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;
    final auth = _navigatorKey.currentContext?.read<AuthProvider>();
    if (auth == null || !auth.isAuthenticated) return;
    auth.logout();
    nav.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  @override
  void dispose() {
    _authTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _resetTimer(),
      onPointerMove: (_) => _resetTimer(),
      onPointerUp: (_) => _resetTimer(),
      child: MaterialApp(
        title: 'Npay',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
        home: const SplashScreen(),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/home': (_) => const AppShell(),
          '/transfer': (_) => const TransferScreen(),
          '/airtime': (_) => const AirtimeScreen(),
          '/data': (_) => const DataScreen(),
          '/bills': (_) => const BillsScreen(),
          '/transactions': (_) => const TransactionsScreen(),
          '/profile': (_) => const ProfileScreen(),
          '/settings': (_) => const SettingsScreen(),
          '/fund-wallet': (_) => const FundWalletScreen(),
        },
      ),
    );
  }
}

