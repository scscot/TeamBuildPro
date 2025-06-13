import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

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
      debugPrint('Error getting user: $e');
      return null;
    }
  }

  Future<void> createUser(Map<String, dynamic> userData) async {
    try {
      await _db
          .collection('users')
          .doc(userData['uid'])
          .set(userData, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error creating user: $e');
      rethrow;
    }
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      debugPrint('Error updating user: $e');
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
      debugPrint('Error getting user by referral code: $e');
      return null;
    }
  }

  Future<List<String>> getAdminAllowedCountries(String adminUid) async {
    try {
      DocumentSnapshot doc =
          await _db.collection('admin_settings').doc(adminUid).get();
      if (doc.exists) {
        return (doc.data() as Map<String, dynamic>?)?['allowed_countries']
                ?.map((e) => e as String)
                .toList() ??
            [];
      }
      return [];
    } catch (e) {
      debugPrint('Error getting admin allowed countries: $e');
      return [];
    }
  }

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String recipientId,
    required String text,
    required FieldValue timestamp,
  }) async {
    try {
      await _db.collection('messages').doc(threadId).collection('chat').add({
        'senderId': senderId,
        'recipientId': recipientId,
        'text': text,
        'timestamp': timestamp,
        'read': false, // MODIFIED: Mark new messages as unread
      });

      await _db.collection('messages').doc(threadId).update({
        'lastMessage': text,
        'lastMessageSenderId': senderId,
        'lastUpdatedAt': timestamp,
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
      rethrow;
    }
  }
}
