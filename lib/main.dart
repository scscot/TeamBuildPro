import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/session_manager.dart';
// Ensure this is imported

// Define your Firebase configuration globally
const Map<String, dynamic> firebaseConfig = {
  'apiKey': "AIzaSyA45ZN9KUuaYT0OHYZ9DmX2Jc8028Ftcvc",
  'authDomain': "teambuilder-plus-fe74d.firebaseapp.com",
  'projectId': "teambuilder-plus-fe74d",
  'storageBucket': "teambuilder-plus-fe74d.firebasestorage.app",
  'messagingSenderId': "312163687148",
  'appId': "1:312163687148:web:43385dff773dab0b3763c9",
  // 'measurementId': "G-G4E4TBBPZ7" // Uncomment if you have measurementId
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // Use default plist-based iOS initialization

  debugPrint('✅ Firebase initialized successfully.');
  await _initializeFCM(); // This should be called after Firebase.initializeApp
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
        debugPrint('✅ FCM token uploaded to Firestore for user: ${user.uid}');
      }
    }

    // Handle token refresh
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

  // Optional: Foreground listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    debugPrint(
        '📩 Foreground FCM Message Received: ${message.notification?.title}');
    // Add local UI/alert logic here if needed
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
        // Pass required args to DashboardScreen
        firebaseConfig: firebaseConfig,
        initialAuthToken: initialAuthToken,
        appId: firebaseConfig['projectId'] as String,
      );
    } else {
      return LoginScreen(
        // Pass required args to LoginScreen
        firebaseConfig: firebaseConfig,
        appId: firebaseConfig['projectId'] as String,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TeamBuild Pro',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        fontFamily: 'Inter', // Assuming Inter font is set up
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
            // Provide fallback if snapshot.data is null (e.g., in case of an unexpected error)
            return snapshot.data ??
                LoginScreen(
                  firebaseConfig: firebaseConfig,
                  appId: firebaseConfig['projectId'] as String,
                );
          }
        },
      ),
    );
  }
}
