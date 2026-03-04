import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/config_provider.dart';
import 'services/api_service.dart';
import 'services/biometric_service.dart';
import 'services/storage_service.dart';
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
  final api = ApiService(storage);

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
      child: const VtuApp(),
    ),
  );
}

class VtuApp extends StatelessWidget {
  const VtuApp({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'VTU Wallet',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: theme.isDark ? ThemeMode.dark : ThemeMode.light,
      home: const _AuthGate(),
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
    );
  }
}

class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await context.read<AuthProvider>().init();
    if (mounted) setState(() => _initialized = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_initialized) return _SplashScreen();

    final auth = context.watch<AuthProvider>();

    if (auth.isAuthenticated) return const AppShell();
    return const LoginScreen();
  }
}

class _SplashScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.darkBgGradient : AppTheme.lightBgGradient,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryIndigo.withValues(alpha: 0.4),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'VTU Wallet',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      color: AppTheme.primaryIndigo,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Nigerian FinTech Wallet',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                color: AppTheme.primaryIndigo,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
