import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tbp/services/eligibility_service.dart';

class InvitationService {
  static final _firestore = FirebaseFirestore.instance;

  /// Sends an invitation if the user is eligible and hasn't been invited yet.
  static Future<void> sendInvitationIfEligible(String userId) async {
    try {
      // 1. Get user data
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ User not found: $userId');
        return;
      }

      final userData = userDoc.data();
      if (userData == null || !userData.containsKey('upline_admin')) {
        print('❌ User has no upline_admin: $userId');
        return;
      }

      final uplineAdmin = userData['upline_admin'];

      // 2. Check eligibility
      final isEligible =
          await EligibilityService.isUserEligible(userId, uplineAdmin);
      if (!isEligible) {
        print('⚠️ User not eligible yet: $userId');
        return;
      }

      // 3. Check if invitation already exists
      final inviteDoc =
          await _firestore.collection('invitations').doc(userId).get();
      if (inviteDoc.exists) {
        print('📨 Invitation already sent to user: $userId');
        return;
      }

      // 4. Send invitation
      await _firestore.collection('invitations').doc(userId).set({
        'userId': userId,
        'adminId': uplineAdmin,
        'sentAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      print('✅ Invitation sent to user: $userId');
    } catch (e) {
      print('❌ Error sending invitation: $e');
    }
  }
}
