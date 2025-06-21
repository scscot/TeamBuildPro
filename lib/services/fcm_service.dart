// lib/services/fcm_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/widgets.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _lastSavedToken;

  Future<void> initialize(BuildContext context) async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      await _conditionallySaveToken(token);

      // Prevent runaway loop by only saving NEW tokens.
      _messaging.onTokenRefresh.listen((newToken) async {
        await _conditionallySaveToken(newToken);
      });
    } else {
      if (kDebugMode) {
        debugPrint('❌ User denied notification permissions.');
      }
    }
  }

  Future<void> _conditionallySaveToken(String? token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || token == null) return;

    try {
      final docRef = _firestore.collection('users').doc(user.uid);
      final doc = await docRef.get();

      final storedToken = doc.data()?['fcm_token'];

      // Skip update if token hasn't changed
      if (storedToken == token || _lastSavedToken == token) return;

      await docRef.update({'fcm_token': token});
      _lastSavedToken = token;

      if (kDebugMode) {
        debugPrint('✅ FCM token saved/updated for user: ${user.uid}');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error saving FCM token: $e');
      }
    }
  }
}
