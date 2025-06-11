import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart'; // Ensure this is correctly imported
import 'package:flutter/foundation.dart'; // Import for debugPrint

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    try {
      DocumentSnapshot doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user: $e'); // Changed print to debugPrint
      return null;
    }
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    try {
      await _db.collection('users').doc(userData['uid']).set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating user: $e'); // Changed print to debugPrint
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user: $e'); // Changed print to debugPrint
      rethrow;
    }
  }

  Future<UserModel?> getUserByReferralCode(String referralCode) async {
    try {
      QuerySnapshot query = await _db
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return UserModel.fromFirestore(query.docs.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error getting user by referral code: $e'); // Changed print to debugPrint
      return null;
    }
  }

  Future<List<String>> getAdminAllowedCountries(String adminUid) async {
    try {
      DocumentSnapshot doc = await _db.collection('admin_settings').doc(adminUid).get();
      if (doc.exists) {
        // Corrected: Cast doc.data() to Map<String, dynamic> before accessing keys
        return (doc.data() as Map<String, dynamic>?)?['allowed_countries']?.map((e) => e as String).toList() ?? [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting admin allowed countries: $e'); // Changed print to debugPrint
      return [];
    }
  }

// In your firestore_service.dart file, add this method to the FirestoreService class:

Future<void> sendMessage({
  required String threadId,
  required String senderId,
  required String recipientId,
  required String text,
  required FieldValue timestamp, // Use FieldValue.serverTimestamp()
}) async {
  try {
    await _db
        .collection('messages')
        .doc(threadId)
        .collection('chat')
        .add({
      'senderId': senderId,
      'recipientId': recipientId, // Store recipient ID for context/future features
      'text': text,
      'timestamp': timestamp,
    });
  } catch (e) {
    debugPrint('Error sending message: $e');
    rethrow;
  }
}


}
