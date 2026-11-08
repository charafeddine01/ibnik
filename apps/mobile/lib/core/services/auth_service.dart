import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  bool get isFirebaseAvailable => Firebase.apps.isNotEmpty;

  Stream<User?> get authStateChanges {
    try {
      if (!isFirebaseAvailable) return const Stream.empty();
      return _auth.authStateChanges();
    } catch (_) {
      return const Stream.empty();
    }
  }

  User? get currentUser {
    try {
      if (!isFirebaseAvailable) return null;
      return _auth.currentUser;
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => currentUser != null;

  bool get isEmailVerified => currentUser?.emailVerified ?? false;

  /// Signs in with 1-Tap Google Sign-In.
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in flow
        return null;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      rethrow;
    }
  }

  /// Signs up with Email and Password, and automatically dispatches verification email.
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Immediately send email verification
      await credential.user?.sendEmailVerification();
      return credential;
    } catch (e) {
      debugPrint('Error creating account with email: $e');
      rethrow;
    }
  }

  /// Signs in with existing Email and Password.
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      rethrow;
    }
  }

  /// Re-sends the verification email to the current unverified user.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  /// Reloads user data to check if email has been verified.
  Future<bool> reloadUserAndCheckVerified() async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.reload();
      return _auth.currentUser?.emailVerified ?? false;
    }
    return false;
  }

  /// Sends a password reset email.
  Future<void> sendPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  /// Signs out from both Firebase and Google.
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _auth.signOut();
  }
}
