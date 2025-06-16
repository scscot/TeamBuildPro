// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/app_constants.dart';
import 'models/user_model.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart'; // Import the new service class

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
    }
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamProvider<UserModel?>.value(
      value: AuthService().onAuthStateChangedAndProfileVerified,
      initialData: null,
      child: MaterialApp(
        title: 'TeamBuild Pro',
        theme: ThemeData(
          primarySwatch: Colors.indigo,
          fontFamily: 'Inter',
        ),
        debugShowCheckedModeBanner: false,
        home: const AuthWrapper(),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);

    if (user != null) {
      // If the user is logged in, initialize FCM services.
      FCMService().initialize();
      return DashboardScreen(appId: firebaseConfig['appId']!);
    } else {
      return LoginScreen(appId: firebaseConfig['appId']!);
    }
  }
}
