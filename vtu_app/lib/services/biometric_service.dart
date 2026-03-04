import 'package:local_auth/local_auth.dart';
import '../config/app_config.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> isAvailable() async {
    if (AppConfig.biometricBypass || AppConfig.useDevFixtures) return true;
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    if (AppConfig.biometricBypass || AppConfig.useDevFixtures) {
      return [BiometricType.fingerprint];
    }
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<bool> authenticate({
    String reason = 'Authenticate to access your wallet',
  }) async {
    if (AppConfig.biometricBypass || AppConfig.useDevFixtures) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> stopAuthentication() async {
    try {
      await _auth.stopAuthentication();
    } catch (_) {}
  }
}
