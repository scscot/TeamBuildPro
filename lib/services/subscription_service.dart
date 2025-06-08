// ignore_for_file: unused_import

import 'package:cloud_functions/cloud_functions.dart';

class SubscriptionService {
  // 🔧 Commented out real function call for testing
  // static final HttpsCallable _checkStatus =
  //     FirebaseFunctions.instance.httpsCallable('checkAdminSubscriptionStatus');

  /// Returns `{ isActive: bool, daysRemaining: int, trialExpired: bool }`
  static Future<Map<String, dynamic>> checkAdminSubscriptionStatus(
      String uid) async {
    // ✅ TEMPORARY OVERRIDE FOR DEVELOPMENT
    print('⚠️ Mocked checkAdminSubscriptionStatus called for uid: $uid');
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
    //   print('❌ Error checking subscription status: $e');
    //   return {
    //     'isActive': false,
    //     'daysRemaining': 0,
    //     'trialExpired': true,
    //   };
    // }
  }
}
