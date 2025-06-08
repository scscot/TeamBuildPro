import 'package:flutter/foundation.dart';

class ReferralService {
  Future<void> trackReferral(String referredBy, String referredUser) async {
    // Log referral connection
    debugPrint('Referral: $referredBy referred $referredUser');
  }
}
