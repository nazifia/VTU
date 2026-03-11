import 'package:local_auth/local_auth.dart';
import '../config/app_config.dart';

class BiometricService {
  final _auth = LocalAuthentication();

  /// Returns true only when biometric hardware is present AND at least one
  /// biometric (fingerprint / face) is enrolled on the device.
  Future<bool> isAvailable() async {
    if (AppConfig.biometricBypass || AppConfig.useDevFixtures) return true;
    try {
      // canCheckBiometrics is true only when hardware is present + biometrics enrolled
      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) return false;
      final types = await _auth.getAvailableBiometrics();
      return types.isNotEmpty;
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

  /// Presents the native biometric prompt.
  ///
  /// Returns `true` on success, `false` on failure or cancellation.
  Future<bool> authenticate({
    String reason = 'Authenticate to access your wallet',
  }) async {
    if (AppConfig.biometricBypass || AppConfig.useDevFixtures) return true;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false,         // allow device PIN/pattern as fallback
        sensitiveTransaction: true,
        persistAcrossBackgrounding: true, // keep prompt alive when app is backgrounded
      );
    } on LocalAuthException catch (e) {
      // User cancelled, locked out, etc. — all treated as auth failure
      switch (e.code) {
        case LocalAuthExceptionCode.userCanceled:
        case LocalAuthExceptionCode.systemCanceled:
        case LocalAuthExceptionCode.timeout:
        case LocalAuthExceptionCode.temporaryLockout:
        case LocalAuthExceptionCode.biometricLockout:
        case LocalAuthExceptionCode.noBiometricsEnrolled:
        case LocalAuthExceptionCode.noCredentialsSet:
          break;
        default:
          break;
      }
      return false;
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
