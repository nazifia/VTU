import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

class ConfigProvider with ChangeNotifier {
  bool get useDevFixtures => AppConfig.useDevFixtures;
  String get apiBaseUrl => AppConfig.apiBaseUrl;
  int get cacheTtlMs => AppConfig.cacheTtlMs;
  bool get biometricBypass => AppConfig.biometricBypass;
  String get devPhone => AppConfig.devPhone;
  String get devPin => AppConfig.devPin;
}
