import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/session_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  debugPrint('✅ Firebase App Config Loaded: \${options.projectId}');
  await _initializeFCM(); // ✅ Initialize FCM
  runApp(const MyApp());
}

Future<void> _initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  // iOS permission request
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    if (token != null) {
      final user = await SessionManager().getCurrentUser();
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': token});
      }
    }

    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) async {
      final user = await SessionManager().getCurrentUser();
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': newToken});
      }
    });
  }

  // Optional foreground message listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint('📩 FCM Message Received: \${message.notification?.title}');
    // Add local UI update/alert logic here if needed
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final user = await SessionManager().getCurrentUser();
    final isLoggedIn = user != null && user.uid.isNotEmpty;
    return isLoggedIn ? const DashboardScreen() : const LoginScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamBuild Pro',
      theme: ThemeData(primarySwatch: Colors.indigo),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _determineStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          } else {
            return snapshot.data ?? const LoginScreen();
          }
        },
      ),
    );
  }
}
