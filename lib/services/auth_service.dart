// lib/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// A stream that emits the current [UserModel] when the auth state changes
  /// and also listens for real-time updates to the user's document in Firestore.
  Stream<UserModel?> get user {
    return _auth.authStateChanges().asyncExpand((firebaseUser) {
      if (firebaseUser == null) {
        // If the user is logged out, emit a single null event.
        return Stream.value(null);
      } else {
        // If the user is logged in, return a stream of their document.
        // The .snapshots() method ensures that any change to the document
        // will automatically be pushed through this stream.
        return _db
            .collection('users')
            .doc(firebaseUser.uid)
            .snapshots()
            .map((snapshot) {
          if (snapshot.exists) {
            return UserModel.fromFirestore(snapshot);
          }
          return null; // Handle case where user doc might not exist yet.
        });
      }
    });
  }

  Future<UserCredential?> signInWithEmailAndPassword(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
