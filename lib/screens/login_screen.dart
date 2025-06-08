// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart';
import 'dashboard_screen.dart';
import 'new_registration_screen.dart';
import '../widgets/header_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

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
    if (await SessionManager.instance.isLogoutCooldownActive(5)) {
      debugPrint('⏳ Skipping biometric login — logout cooldown in effect');
      return;
    }

    final enabled = await SessionManager.instance.getBiometricEnabled();
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
          final userData =
              await FirestoreService().getUserData(currentUser.uid);

          if (userData != null) {
            final fullUser =
                UserModel.fromMap(userData).copyWith(uid: currentUser.uid);
            await SessionManager.instance.setCurrentUser(fullUser);
            if (!mounted) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
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
      await SessionManager.instance.setCurrentUser(user);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const DashboardScreen()),
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
      appBar: const AppHeaderWithMenu(),
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
                validator: (value) => value == null || value.isEmpty
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
                        builder: (context) => const NewRegistrationScreen()),
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
