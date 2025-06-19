// lib/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/message_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
    } catch (e) {
      debugPrint('Error getting user: $e');
    }
    return null;
  }

  // MODIFIED: This is the definitive, robust implementation.
  Future<void> updateUser(String uid, Map<String, dynamic> data) async {
    try {
      debugPrint("FirestoreService: Updating user $uid with data: $data");
      await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
      debugPrint("FirestoreService: Update for $uid successful.");
    } catch (e) {
      debugPrint("FirestoreService: Error updating user $uid: $e");
      // Re-throw the exception so the UI can catch it.
      rethrow;
    }
  }

  Future<void> sendMessage({
    required String threadId,
    required String senderId,
    required String text,
  }) async {
    try {
      final message = Message(
        senderId: senderId,
        text: text,
        timestamp: DateTime.now(),
      );
      await _db
          .collection('chats')
          .doc(threadId)
          .collection('messages')
          .add(message.toMap());

      await _db.collection('chats').doc(threadId).set({
        'lastMessage': text,
        'lastMessageTimestamp': FieldValue.serverTimestamp(),
        'participants': threadId.split('_'),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }
}
