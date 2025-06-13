// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart';
import 'new_registration_screen.dart';
import '../widgets/header_widgets.dart';

class LoginScreen extends StatefulWidget {
  // REMOVED: final Map<String, dynamic> firebaseConfig;
  final String appId;

  const LoginScreen({
    super.key,
    // REMOVED: required this.firebaseConfig,
    required this.appId,
    required Map<String, dynamic> firebaseConfig,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tryBiometricLogin();
  }

  Future<void> _tryBiometricLogin() async {
    if (await SessionManager().isLogoutCooldownActive(5)) {
      debugPrint('⏳ Skipping biometric login — logout cooldown in effect');
      return;
    }

    final enabled = await SessionManager().getBiometricEnabled();
    if (!enabled) return;

    final auth = LocalAuthentication();
    final canAuth =
        await auth.canCheckBiometrics && await auth.isDeviceSupported();
    if (!canAuth) return;

    try {
      final didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to login',
        options:
            const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );

      if (!mounted) return;

      if (didAuthenticate) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null && currentUser.uid.isNotEmpty) {
          final DocumentSnapshot<Map<String, dynamic>> userDoc =
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();

          if (userDoc.exists) {
            final fullUser = UserModel.fromFirestore(userDoc);
            await SessionManager().setCurrentUser(fullUser);
            if (!mounted) return;

            final String? initialAuthToken = await currentUser.getIdToken();

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => DashboardScreen(
                  appId: widget.appId,
                  firebaseConfig: {},
                  initialAuthToken: initialAuthToken,
                ),
              ),
            );
            return;
          }
        }
        debugPrint('❌ No user session found after biometric login');
      }
    } catch (e) {
      debugPrint('❌ Biometric login error: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = await AuthService().login(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      await SessionManager().setCurrentUser(user);
      if (!mounted) return;

      final String? currentAuthToken =
          await FirebaseAuth.instance.currentUser?.getIdToken();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => DashboardScreen(
            appId: widget.appId,
            firebaseConfig: {},
            initialAuthToken: currentAuthToken,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(
        initialAuthToken: null,
        appId: widget.appId,
        firebaseConfig: {},
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) =>
                    value == null || value.isEmpty ? 'Enter your email' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: (value) => value == null || value.length < 6
                    ? 'Enter your password'
                    : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _login,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () async {
                  final email = _emailController.text.trim();
                  if (email.isEmpty) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Please enter your email first.')),
                    );
                    return;
                  }
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: email);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Password reset email sent.')),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to send reset email: $e')),
                    );
                  }
                },
                child: const Text('Forgot Password?'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => NewRegistrationScreen(
                              appId: widget.appId,
                              firebaseConfig: {},
                            )),
                  );
                },
                child: const Text('Create Account'),
              )
            ],
          ),
        ),
      ),
    );
  }
}
