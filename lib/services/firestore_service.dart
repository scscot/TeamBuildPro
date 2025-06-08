import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:flutter/foundation.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> createUser(Map<String, dynamic> userMap) async {
    final String uid = userMap['uid'];
    await _firestore.collection('users').doc(uid).set(userMap);

    if (userMap['role'] == 'admin') {
      await _firestore.collection('admin_settings').doc(uid).set({
        'direct_sponsor_min': 1,
        'total_team_min': 1,
        'countries': [],
        'biz_opp': '',
        'biz_opp_ref_url': '',
      });
    }
  }

  Future<Map<String, dynamic>?> getUserData(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data();
    }
    return null;
  }

  Future<UserModel?> getUser(String uid) async {
    final doc = await _firestore.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<void> updateUser(String uid, Map<String, dynamic> updates) async {
    if (uid.isEmpty) {
      debugPrint(
          '❌ FirestoreService.updateUser — UID is empty. Cannot update user.');
      throw ArgumentError('User ID cannot be empty');
    }
    debugPrint('📡 FirestoreService.updateUser — Updating UID: $uid');
    debugPrint('📦 Update Payload: $updates');
    await _firestore.collection('users').doc(uid).update(updates);
  }

  Future<void> updateUserField(String uid, String field, dynamic value) async {
    try {
      await _firestore.collection('users').doc(uid).update({field: value});
      debugPrint(
          '✅ Firestore field "$field" updated successfully for user $uid');
    } catch (e) {
      debugPrint('❌ Failed to update field "$field" for user $uid: $e');
      rethrow;
    }
  }

  Future<void> updateIsUpgraded(String uid, bool upgraded) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isUpgraded': upgraded,
      });
      debugPrint('✅ isUpgraded updated to $upgraded for user $uid');
    } catch (e) {
      debugPrint('❌ Failed to update isUpgraded for $uid: $e');
      rethrow;
    }
  }

  Future<String> getUserFullName(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      final data = doc.data();
      if (data == null) return 'N/A';

      if (data['fullName'] != null && data['fullName'] is String) {
        return data['fullName'];
      } else if (data['firstName'] != null && data['lastName'] != null) {
        return '${data['firstName']} ${data['lastName']}';
      } else {
        return 'N/A';
      }
    } catch (e) {
      debugPrint('❌ Error retrieving user full name: $e');
      return 'N/A';
    }
  }

  Future<List<UserModel>> getDownlineUsers(String referredBy) async {
    final querySnapshot = await _firestore
        .collection('users')
        .where('referredBy', isEqualTo: referredBy)
        .get();

    return querySnapshot.docs
        .map((doc) => UserModel.fromFirestore(doc))
        .toList();
  }

  Future<String> getSponsorNameByReferralCode(String referralCode) async {
    try {
      final userQuery = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: referralCode)
          .limit(1)
          .get();

      if (userQuery.docs.isNotEmpty) {
        final data = userQuery.docs.first.data();
        if (data['fullName'] != null && data['fullName'] is String) {
          return data['fullName'];
        } else if (data['firstName'] != null && data['lastName'] != null) {
          return '${data['firstName']} ${data['lastName']}';
        }
      }
      return 'N/A';
    } catch (e) {
      debugPrint('❌ Error retrieving sponsor name by referralCode: $e');
      return 'N/A';
    }
  }

  Future<UserModel?> getUserByReferralCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return UserModel.fromFirestore(snapshot.docs.first);
      }
    } catch (e) {
      debugPrint('❌ Error in getUserByReferralCode: $e');
    }
    return null;
  }

  Future<void> incrementUplineCounts(String referralCode) async {
    String? currentCode = referralCode;
    final visited = <String>{};

    while (currentCode != null && !visited.contains(currentCode)) {
      visited.add(currentCode);
      final snapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: currentCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) break;

      final doc = snapshot.docs.first;
      final data = doc.data();
      final uid = doc.id;
      final isDirect = visited.length == 1;

      final updates = <String, dynamic>{};
      if (isDirect) updates['direct_sponsor_count'] = FieldValue.increment(1);
      updates['total_team_count'] = FieldValue.increment(1);

      await _firestore.collection('users').doc(uid).update(updates);

      currentCode = data['referredBy'];
    }
  }

  // PATCH START: Send a message between users with allowedUsers thread metadata
  Future<void> sendMessage({
    required String senderId,
    required String recipientId,
    required String text,
    Map<String, dynamic>? extraData,
  }) async {
    final threadId = _generateThreadId(senderId, recipientId);
    final threadRef = _firestore.collection('messages').doc(threadId);

    // Ensure allowedUsers field is present for Firestore rules
    await threadRef.set({
      'allowedUsers': [senderId, recipientId],
    }, SetOptions(merge: true));

    final messageData = {
      'senderId': senderId,
      'recipientId': recipientId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
      if (extraData != null) ...extraData,
    };

    await threadRef.collection('chat').add(messageData);
  }
  // PATCH END

  String _generateThreadId(String uid1, String uid2) {
    final sortedIds = [uid1, uid2]..sort();
    return '${sortedIds[0]}_${sortedIds[1]}';
  }
}
