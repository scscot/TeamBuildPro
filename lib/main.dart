import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'config/app_constants.dart';
import 'models/user_model.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // MODIFIED: The initialization logic is simplified.
  // Since AppDelegate now handles configuration, Dart only needs to
  // connect to the existing native Firebase instance.
  await Firebase.initializeApp();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        StreamProvider<UserModel?>(
          create: (context) => context.read<AuthService>().user,
          initialData: null,
          catchError: (_, error) {
            debugPrint("Error in auth stream: $error");
            return null;
          },
        ),
      ],
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
    final user = context.watch<UserModel?>();
    final appId = firebaseConfig['appId']!;

    if (user != null) {
      FCMService().initialize(context);
      return DashboardScreen(appId: appId);
    } else {
      return LoginScreen(appId: appId);
    }
  }
}
