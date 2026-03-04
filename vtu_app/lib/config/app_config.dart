import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

class AppConfig {
  // Can still be overridden at build time with --dart-define=API_BASE_URL=...
  static const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Resolves the correct base URL at runtime:
  /// - Web / Windows desktop → http://localhost:8000/api/v1
  /// - Android emulator      → http://10.0.2.2:8000/api/v1   (emulator loopback)
  /// - iOS simulator         → http://127.0.0.1:8000/api/v1
  /// - Physical device       → must pass --dart-define=API_BASE_URL=http://<LAN-IP>:8000/api/v1
  static String get apiBaseUrl {
    if (_envApiBaseUrl.isNotEmpty) return _envApiBaseUrl;
    if (kIsWeb) return 'http://localhost:8000/api/v1';
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      return 'http://localhost:8000/api/v1';
    }
    if (Platform.isAndroid) return 'http://10.0.2.2:8000/api/v1';
    // iOS simulator
    return 'http://127.0.0.1:8000/api/v1';
  }

  static const bool useDevFixtures = bool.fromEnvironment(
    'USE_DEV_FIXTURES',
    defaultValue: false,
  );

  static const int cacheTtlMs = int.fromEnvironment(
    'CACHE_TTL_MS',
    defaultValue: 1500,
  );

  static const String devPhone = String.fromEnvironment(
    'DEV_PHONE',
    defaultValue: '+2348012345678',
  );

  static const String devPin = String.fromEnvironment(
    'DEV_PIN',
    defaultValue: '1234',
  );

  static const bool biometricBypass = bool.fromEnvironment(
    'BIOMETRIC_BYPASS',
    defaultValue: false,
  );
}
