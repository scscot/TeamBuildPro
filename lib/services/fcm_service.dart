// lib/services/fcm_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> initialize() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Get the token and save it to the database for the current user
      await _saveToken();

      // Listen for token refreshes
      _messaging.onTokenRefresh.listen((_) => _saveToken());
    } else {
      if (kDebugMode) {
        print('User denied notification permissions.');
      }
    }
  }

  Future<void> _saveToken() async {
    final user = FirebaseAuth.instance.currentUser;
    final token = await _messaging.getToken();

    if (user != null && token != null) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': token});
        if (kDebugMode) {
          print('✅ FCM token saved/updated for user: ${user.uid}');
        }
      } catch (e) {
        if (kDebugMode) {
          print('❌ Error saving FCM token: $e');
        }
      }
    }
  }
}
