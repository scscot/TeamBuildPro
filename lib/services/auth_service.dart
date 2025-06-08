import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<UserModel> login(String email, String password) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      final uid = result.user?.uid;
      if (uid == null) throw Exception('User ID not found after login.');

      final user = await FirestoreService().getUser(uid);
      if (user == null) throw Exception('User not found in Firestore.');

      debugPrint('✅ AuthService — Login success. UID: $uid');
      return user;
    } catch (e) {
      debugPrint('❌ AuthService — Login failed: $e');
      rethrow;
    }
  }

  Future<UserModel> register(String email, String password) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      final uid = result.user?.uid;
      if (uid == null) throw Exception('User ID not found after registration.');

      debugPrint('✅ AuthService — Registration success. UID: $uid');

      // Return minimal model — full Firestore hydration happens after profile creation
      return UserModel(
        uid: uid,
        email: email,
      );
    } catch (e) {
      debugPrint('❌ AuthService — Registration failed: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    debugPrint('👋 AuthService — User signed out');
  }
}
