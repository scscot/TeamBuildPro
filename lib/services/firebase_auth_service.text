import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirebaseAuthService {
  final String apiKey;

  FirebaseAuthService({required this.apiKey});

  Future<bool> signIn(String email, String password) async {
    final url =
        'https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey';

    final response = await http.post(
      Uri.parse(url),
      body: json.encode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
      headers: {'Content-Type': 'application/json'},
    );

    if (response.statusCode == 200) {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && currentUser.uid.isNotEmpty) {
        final userData = {
          'uid': currentUser.uid,
          'email': currentUser.email,
          'displayName': currentUser.displayName,
        };
        final user = UserModel.fromMap(userData);
        await SessionManager.instance.saveSession(user);
      }
      return true;
    } else {
      debugPrint('Login failed: ${response.body}');
      return false;
    }
  }
}
