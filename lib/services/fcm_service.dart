import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kDebugMode; // Import kDebugMode
import 'dart:developer' as developer; // Import the developer package for logging
import 'session_manager.dart';

// A simple log function that only prints in debug mode
void _log(String message) {
  if (kDebugMode) {
    developer.log(message, name: 'FCMService');
  }
}

Future<void> storeDeviceToken(String token) async {
  final user = await SessionManager().getCurrentUser();
  if (user != null && user.uid.isNotEmpty) {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcm_token': token});
      _log('✅ FCM token stored successfully for user: ${user.uid}');
    } catch (e) {
      _log('❌ Error storing FCM token for user: ${user.uid}, Error: $e');
    }
  } else {
    _log('⚠️ User not logged in or UID is empty, cannot store FCM token.');
  }
}

Future<void> initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  try {
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      if (token != null) {
        _log('Registered FCM Token: $token');
        await storeDeviceToken(token);
      } else {
        _log('⚠️ FCM Token is null after requestPermission.');
      }
    } else {
      _log('❌ User denied notification permissions. Authorization status: ${settings.authorizationStatus}');
    }
  } catch (e) {
    _log('❌ Error requesting FCM permissions or getting token: $e');
  }

  // Listen for messages while the app is in the foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    _log('📩 FCM Message Received: ${message.notification?.title}');
    // Optional: Add in-app alert logic here (e.g., displaying a local notification)
  });

  // Handle messages when the app is opened from a terminated state via a notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _log('🚀 App opened from terminated state via FCM message: ${message.notification?.title}');
    // Handle navigation or specific actions based on the notification data
  });

  // Handle background messages (requires a top-level function in main.dart)
  // FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  // (Note: _firebaseMessagingBackgroundHandler should be defined outside a class in main.dart)
  _log('✅ FCM initialized and message listeners set up.');
}
