// lib/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';
import 'new_registration_screen.dart';
import '../widgets/header_widgets.dart'; // MODIFIED: Added header import

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

  Future<void> _login() async {
    if (!_formKey.currentState!.validate() || _isLoading) return;
    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      await authService.signInWithEmailAndPassword(
          _emailController.text.trim(), _passwordController.text.trim());
      // Navigation will be handled by the AuthWrapper in main.dart
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(e.message ?? 'Login failed. Please try again.'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _sha256(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<OAuthCredential> _getAppleCredential() async {
    final rawNonce = _sha256(DateTime.now().toIso8601String());
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName
      ],
      nonce: rawNonce,
    );
    return OAuthProvider("apple.com").credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );
  }

  Future<OAuthCredential> _getGoogleCredential() async {
    final GoogleSignIn googleSignIn = GoogleSignIn();
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    final GoogleSignInAuthentication? googleAuth =
        await googleUser?.authentication;
    if (googleAuth == null) {
      throw FirebaseAuthException(
          code: 'ERROR_MISSING_GOOGLE_AUTH', message: 'Missing Google Auth');
    }
    return GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
  }

  Future<void> _signInWithSocial(
      Future<OAuthCredential> Function() getCredential) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final credential = await getCredential();
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Social sign-in failed: ${e.toString()}'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // MODIFIED: Replaced standard AppBar with the custom header widget.
      appBar: AppHeaderWithMenu(appId: widget.appId),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // MODIFIED: Added a Text widget to serve as the page title.
              Text(
                'Log In',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 24),
              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _emailController,
                      decoration:
                          const InputDecoration(labelText: 'Email Address'),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) =>
                          v == null || v.isEmpty ? 'Email is required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Password is required'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 3),
                            )
                          : const Text('Login'),
                    ),
                    if (Platform.isIOS) ...[
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const FaIcon(FontAwesomeIcons.apple,
                            color: Colors.white, size: 22),
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
                    ],
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
                                  builder: (context) => NewRegistrationScreen(
                                      appId: widget.appId))),
                          child: const Text('Create Account'))
                    ])
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
