import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart'; // Make sure this is correctly imported

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();
  static const String _userKey = 'currentUser';
  static const String _biometricEnabledKey = 'biometricEnabled';
  static const String _lastLogoutTimestampKey = 'lastLogoutTimestamp';

  factory SessionManager() {
    return _instance;
  }

  SessionManager._internal();

  Future<UserModel?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_userKey);
    if (userJson != null) {
      return UserModel.fromMap(jsonDecode(userJson) as Map<String, dynamic>); // Use fromMap
    }
    return null;
  }

  Future<void> setCurrentUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey, jsonEncode(user.toMap())); // Use toMap
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userKey);
    await prefs.setInt(_lastLogoutTimestampKey, DateTime.now().millisecondsSinceEpoch);
  }

  Future<bool> getBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
  }

  Future<bool> isLogoutCooldownActive(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    final lastLogoutTimestamp = prefs.getInt(_lastLogoutTimestampKey);
    if (lastLogoutTimestamp == null) return false;

    final lastLogoutDateTime = DateTime.fromMillisecondsSinceEpoch(lastLogoutTimestamp);
    final now = DateTime.now();
    final difference = now.difference(lastLogoutDateTime).inMinutes;

    return difference < minutes;
  }
}
