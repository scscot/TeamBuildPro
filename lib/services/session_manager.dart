import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

class SessionManager {
  static final SessionManager instance = SessionManager();

  static const String _userKey = 'user';
  static const String _biometricKey = 'biometric_enabled';
  static const String _logoutTimeKey = 'last_logout_time';

  Future<void> setCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    final userMap = jsonEncode(user.toMap());
    await prefs.setString(_userKey, userMap);
    debugPrint('📂 SessionManager — User session saved with UID: ${user.uid}');
  }

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString(_userKey);
    if (userData == null) {
      debugPrint('⚠️ SessionManager — No session data found');
      return null;
    }
    try {
      final map = jsonDecode(userData);
      final user = UserModel.fromMap(map);
      if (user.uid.isEmpty) {
        debugPrint('⚠️ SessionManager — Decoded user has empty UID');
        return null;
      }
      debugPrint('✅ SessionManager — User hydrated: ${user.uid}');
      return user;
    } catch (e) {
      debugPrint('❌ Failed to decode user session: $e');
      return null;
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.remove(_biometricKey);
    await prefs.remove(_logoutTimeKey);
    debugPrint('🧹 SessionManager — Session cleared');
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);
  }

  Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricKey) ?? false;
  }

  Future<void> setLastLogoutTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_logoutTimeKey, time.toIso8601String());
  }

  Future<DateTime?> getLastLogoutTime() async {
    final prefs = await SharedPreferences.getInstance();
    final isoTime = prefs.getString(_logoutTimeKey);
    return isoTime != null ? DateTime.tryParse(isoTime) : null;
  }

  Future<bool> isLogoutCooldownActive(int minutes) async {
    final lastLogout = await getLastLogoutTime();
    if (lastLogout == null) return false;
    final elapsed = DateTime.now().difference(lastLogout);
    return elapsed.inMinutes < minutes;
  }

  Future<bool> getBiometricEnabled() async {
    return isBiometricEnabled();
  }

  // PATCH START: alias for compatibility with FirebaseAuthService
  Future<void> saveSession(UserModel user) async {
    await setCurrentUser(user);
  }
  // PATCH END
}
