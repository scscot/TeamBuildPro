import 'package:cloud_firestore/cloud_firestore.dart';

class EligibilityService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<bool> isUserEligible(String userId, String adminUid) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final adminSettingsDoc =
          await _firestore.collection('admin_settings').doc(adminUid).get();

      if (!userDoc.exists || !adminSettingsDoc.exists) return false;

      final user = userDoc.data()!;
      final settings = adminSettingsDoc.data()!;

      final int userDirect = user['direct_sponsor_count'] ?? 0;
      final int userTotal = user['total_team_count'] ?? 0;
      final String userCountry = user['country'] ?? '';

      final int minDirect = settings['direct_sponsor_min'] ?? 1;
      final int minTotal = settings['total_team_min'] ?? 1;
      final List<dynamic> allowedCountries = settings['countries'] ?? [];

      final isDirectOk = userDirect >= minDirect;
      final isTotalOk = userTotal >= minTotal;
      final isCountryOk = allowedCountries.contains(userCountry);

      return isDirectOk && isTotalOk && isCountryOk;
    } catch (e) {
      print('❌ Eligibility check failed: $e');
      return false;
    }
  }
}
