import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'session_manager.dart';

Future<void> storeDeviceToken(String token) async {
  final user = await SessionManager().getCurrentUser();
  if (user != null && user.uid.isNotEmpty) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .update({'fcm_token': token});
  }
}

Future<void> initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    if (token != null) {
      await storeDeviceToken(token);
    }
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    // Optional: Add in-app alert logic
    print('📩 FCM Message Received: \${message.notification?.title}');
  });
}
