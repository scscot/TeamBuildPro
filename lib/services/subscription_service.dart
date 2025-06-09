// import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // Import kDebugMode
import 'dart:developer' as developer; // Import the developer package for logging


class SubscriptionService {
  // A simple log function that only prints in debug mode
  static void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'SubscriptionService');
    }
  }

  // 🔧 Commented out real function call for testing
  // static final HttpsCallable _checkStatus =
  //     FirebaseFunctions.instance.httpsCallable('checkAdminSubscriptionStatus');

  /// Returns `{ isActive: bool, daysRemaining: int, trialExpired: bool }`
  static Future<Map<String, dynamic>> checkAdminSubscriptionStatus(
      String uid) async {
    // ✅ TEMPORARY OVERRIDE FOR DEVELOPMENT
    _log('⚠️ Mocked checkAdminSubscriptionStatus called for uid: $uid');
    return {
      'isActive': true,
      'daysRemaining': 99,
      'trialExpired': false,
    };

    // ❌ ORIGINAL (commented out for now)
    // try {
    //   final result = await _checkStatus.call({'uid': uid});
    //   final data = Map<String, dynamic>.from(result.data);
    //   return data;
    // } catch (e) {
    //   _log('❌ Error checking subscription status: $e'); // Replaced print
    //   return {
    //     'isActive': false,
    //     'daysRemaining': 0,
    //     'trialExpired': true,
    //   };
    // }
  }
}
