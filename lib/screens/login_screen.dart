// lib/screens/login_screen.dart
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;
import '../services/auth_service.dart';
import 'new_registration_screen.dart';
import '../widgets/header_widgets.dart';

class LoginScreen extends StatefulWidget {
  final String appId;
  const LoginScreen({super.key, required this.appId});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // REMOVED: The _tryBiometricLogin method and its call in initState are no longer needed.

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await AuthService()
          .login(_emailController.text.trim(), _passwordController.text.trim());
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithSocial(
      Future<AuthCredential> Function() getCredential) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final credential = await getCredential();
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Sign-in failed: ${e.toString()}')));
      }
      debugPrint("Social Sign-In failed: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<AuthCredential> _getGoogleCredential() async {
    final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
    if (googleUser == null) throw Exception("Sign-in cancelled");

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    return GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken);
  }

  Future<AuthCredential> _getAppleCredential() async {
    final rawNonce = _generateNonce();
    final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
      nonce: hashedNonce,
    );
    return OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode);
  }

  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    return base64Url
        .encode(List<int>.generate(length, (i) => random.nextInt(256)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Welcome Back!',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Sign in to your account',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 16, color: Colors.grey.shade600)),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                      labelText: 'Email', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.isEmpty || !v.contains('@')
                      ? 'Enter a valid email'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                      labelText: 'Password', border: OutlineInputBorder()),
                  validator: (v) => v == null || v.length < 6
                      ? 'Password must be at least 6 characters'
                      : null,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8))),
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : const Text('Login', style: TextStyle(fontSize: 16)),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () async {
                    if (_emailController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'Please enter your email to reset the password.')));
                      return;
                    }
                    final messenger = ScaffoldMessenger.of(context);
                    await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: _emailController.text.trim());
                    messenger.showSnackBar(const SnackBar(
                        content: Text('Password reset email sent.')));
                  },
                  child: const Text('Forgot Password?'),
                ),
                const SizedBox(height: 24),
                Row(children: [
                  const Expanded(child: Divider()),
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('OR',
                          style: TextStyle(color: Colors.grey.shade600))),
                  const Expanded(child: Divider())
                ]),
                const SizedBox(height: 24),
                if (Platform.isIOS || Platform.isMacOS)
                  ElevatedButton.icon(
                    icon: const FaIcon(FontAwesomeIcons.apple, size: 22),
                    label: const Text('Sign in with Apple'),
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithSocial(_getAppleCredential),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const FaIcon(FontAwesomeIcons.google, size: 20),
                  label: const Text('Sign in with Google'),
                  onPressed: _isLoading
                      ? null
                      : () => _signInWithSocial(_getGoogleCredential),
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text("Don't have an account?"),
                  TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (context) =>
                                  NewRegistrationScreen(appId: widget.appId))),
                      child: const Text('Create Account'))
                ])
              ],
            ),
          ),
        ),
      ),
    );
  }
}
