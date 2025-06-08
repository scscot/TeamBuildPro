import 'package:local_auth/local_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricAuthService {
  static const _biometricKey = 'biometric_enabled';
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      return await _auth.canCheckBiometrics && await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('❌ Biometric check failed: $e');
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Please authenticate to continue',
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
    } catch (e) {
      debugPrint('❌ Biometric auth error: $e');
      return false;
    }
  }

  Future<void> setBiometricPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);
  }

  Future<bool> getBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  Future<void> clearBiometricPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_biometricKey);
  }
}
