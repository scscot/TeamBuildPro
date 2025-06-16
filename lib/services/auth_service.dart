// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<UserModel?> get onAuthStateChangedAndProfileVerified {
    return _auth.authStateChanges().asyncMap((User? user) async {
      if (user == null) {
        return null;
      }
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        return UserModel.fromFirestore(userDoc);
      } else {
        return null;
      }
    });
  }

  Future<void> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw Exception(_getFirebaseAuthErrorMessage(e.code));
    } catch (e) {
      throw Exception('An unexpected error occurred: $e');
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  String _getFirebaseAuthErrorMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'email-already-in-use':
        return 'The email address is already in use by another account.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
