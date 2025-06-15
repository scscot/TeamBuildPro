// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

// --- ADD: Import for Font Awesome icons ---
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:io' show Platform;

import '../services/auth_service.dart';
import '../services/session_manager.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'dashboard_screen.dart';
import 'new_registration_screen.dart';
import '../widgets/header_widgets.dart';

class LoginScreen extends StatefulWidget {
  final String appId;

  const LoginScreen({
    super.key,
    required this.appId,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _tryBiometricLogin();
  }

  Future<void> _tryBiometricLogin() async {
    if (await SessionManager().isLogoutCooldownActive(5)) return;
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
      if (!mounted || !didAuthenticate) return;
      _navigateToDashboard();
    } catch (e) {
      debugPrint('❌ Biometric login error: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final user = await AuthService()
          .login(_emailController.text.trim(), _passwordController.text.trim());
      await SessionManager().setCurrentUser(user);
      if (!mounted) return;
      _navigateToDashboard();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Login failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _handleSocialSignIn(userCredential);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Google Sign-In failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signInWithApple() async {
    setState(() => _isLoading = true);
    try {
      final rawNonce = _generateNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName
        ],
        nonce: hashedNonce,
      );

      final OAuthCredential credential = OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      await _handleSocialSignIn(userCredential, appleCredential);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Apple Sign-In failed: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSocialSignIn(UserCredential userCredential,
      [dynamic appleCredential]) async {
    final User? user = userCredential.user;
    if (user == null) return;

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await userDocRef.get();

    if (!doc.exists) {
      String? firstName, lastName;

      if (appleCredential is AuthorizationCredentialAppleID) {
        firstName = appleCredential.givenName;
        lastName = appleCredential.familyName;
      } else {
        final nameParts = user.displayName?.split(' ') ?? [];
        firstName = nameParts.isNotEmpty ? nameParts.first : null;
        lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : null;
      }

      final newUser = UserModel(
        uid: user.uid,
        email: user.email,
        firstName: firstName,
        lastName: lastName,
        photoUrl: user.photoURL,
        role: 'user',
        createdAt: DateTime.now(),
      );
      await _firestoreService.createUser(newUser.toMap());
      await SessionManager().setCurrentUser(newUser);
    } else {
      final existingUser = UserModel.fromFirestore(doc);
      await SessionManager().setCurrentUser(existingUser);
    }

    if (!mounted) return;
    _navigateToDashboard();
  }

  Future<void> _navigateToDashboard() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final initialAuthToken = await currentUser.getIdToken();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
          builder: (context) => DashboardScreen(
              appId: widget.appId, initialAuthToken: initialAuthToken)),
    );
  }

  String _generateNonce([int length = 32]) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppHeaderWithMenu(initialAuthToken: null, appId: widget.appId),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Welcome Back!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sign in to your account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
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
                        borderRadius: BorderRadius.circular(8)),
                  ),
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
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                          email: _emailController.text.trim());
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Password reset email sent.')));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Failed to send reset email: $e')));
                    }
                  },
                  child: const Text('Forgot Password?'),
                ),
                const SizedBox(height: 24),

                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text('OR',
                          style: TextStyle(color: Colors.grey.shade600)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),

                // --- CORRECTED: Social Login Buttons ---
                // Using standard ElevatedButton with a Row child for layout control

                if (Platform.isIOS || Platform.isMacOS)
                  ElevatedButton(
                    onPressed: _isLoading ? null : _signInWithApple,
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        FaIcon(FontAwesomeIcons.apple, size: 22),
                        SizedBox(width: 12),
                        Text('Sign in with Apple'),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _isLoading ? null : _signInWithGoogle,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.black,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      FaIcon(FontAwesomeIcons.google, size: 20),
                      SizedBox(width: 12),
                      Text('Sign in with Google'),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (context) =>
                                NewRegistrationScreen(appId: widget.appId)),
                      ),
                      child: const Text('Create Account'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
