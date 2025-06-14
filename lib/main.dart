import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/session_manager.dart';
import 'config/app_constants.dart'; // ✅ Correct import for firebaseConfig

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: FirebaseOptions(
          apiKey: firebaseConfig['apiKey']!,
          authDomain: firebaseConfig['authDomain']!,
          projectId: firebaseConfig['projectId']!,
          storageBucket: firebaseConfig['storageBucket']!,
          messagingSenderId: firebaseConfig['messagingSenderId']!,
          appId: firebaseConfig['appId']!,
        ),
      );
      debugPrint('✅ Firebase initialized successfully.');
    } else {
      debugPrint('⚠️ Firebase already initialized — skipping.');
    }
  } catch (e) {
    if (e.toString().contains('already exists')) {
      debugPrint('⚠️ Caught duplicate Firebase init — ignoring.');
    } else {
      rethrow;
    }
  }

  runApp(const MyApp());

  // ✅ Delay FCM init until widget tree is ready
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _initializeFCM();
  });
}

void _initializeFCM() async {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  debugPrint(
      '🔐 Notification permission status: ${settings.authorizationStatus}');

  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    final token = await messaging.getToken();
    debugPrint('📲 Current FCM Token: $token');

    if (token != null) {
      final user = await SessionManager().getCurrentUser();
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': token});
        debugPrint('✅ FCM token uploaded for user: ${user.uid}');
      }
    }

    messaging.onTokenRefresh.listen((newToken) async {
      debugPrint('🔄 FCM token refreshed: $newToken');
      final user = await SessionManager().getCurrentUser();
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update({'fcm_token': newToken});
      }
    });
  } else {
    debugPrint('⚠️ Notification permissions not granted.');
  }

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(
        '📩 Foreground FCM Message Received: ${message.notification?.title}');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  Future<Widget> _determineStartScreen() async {
    final user = await SessionManager().getCurrentUser();
    final isLoggedIn = user != null && user.uid.isNotEmpty;

    if (isLoggedIn) {
      final String? initialAuthToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      return DashboardScreen(
        initialAuthToken: initialAuthToken,
        appId: firebaseConfig['appId']!,
      );
    } else {
      return LoginScreen(
        appId: firebaseConfig['appId']!,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamBuild Pro',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter',
      ),
      debugShowCheckedModeBanner: false,
      home: FutureBuilder<Widget>(
        future: _determineStartScreen(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
                body: Center(child: CircularProgressIndicator()));
          } else if (snapshot.hasError) {
            debugPrint('Error determining start screen: ${snapshot.error}');
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Error loading app: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            );
          } else {
            return snapshot.data ??
                LoginScreen(appId: firebaseConfig['appId']!);
          }
        },
      ),
    );
  }
}
