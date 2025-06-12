import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'dart:developer' as developer;
import '../config/app_constants.dart';

class EligibilityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static void _log(String message) {
    if (kDebugMode) {
      developer.log(message, name: 'EligibilityService');
    }
  }

  static Future<bool> isUserEligible(String userId, String adminUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final adminSettingsDoc =
          await _firestore.collection('admin_settings').doc(adminUid).get();

      if (!userDoc.exists || !adminSettingsDoc.exists) {
        _log(
            '❌ User or admin settings not found for eligibility check: UserId=$userId, AdminUid=$adminUid');
        return false;
      }

      final user = userDoc.data()!;
      final settings = adminSettingsDoc.data()!;

      final int userDirect = user['direct_sponsor_count'] ?? 0;
      final int userTotal = user['total_team_count'] ?? 0;
      final String userCountry = user['country'] ?? '';

      // FIXED: 'const' changed to 'final' because the initializer is not a compile-time constant.
      final int minDirect = AppConstants.projectWideDirectSponsorMin;
      final int minTotal = AppConstants.projectWideTotalTeamMin;

      final List<dynamic> allowedCountries = settings['countries'] ?? [];

      final isDirectOk = userDirect >= minDirect;
      final isTotalOk = userTotal >= minTotal;
      final isCountryOk = allowedCountries.contains(userCountry);

      _log(
          'ℹ️ Eligibility check results for user: $userId - DirectOK: $isDirectOk, TotalOK: $isTotalOk, CountryOK: $isCountryOk');

      return isDirectOk && isTotalOk && isCountryOk;
    } catch (e) {
      _log('❌ Eligibility check failed for user: $userId, Error: $e');
      return false;
    }
  }
}
