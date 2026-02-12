// auth_service.dart - Handles all Firebase Authentication logic
// Provides methods for login, register, and logout

import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Firebase Auth instance
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get user ID (returns empty string if not logged in)
  String get userId => _auth.currentUser?.uid ?? '';

  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Stream of auth state changes (used in AuthWrapper)
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Register new user with email and password
  // Returns null on success, error message on failure
  Future<String?> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Create new user account
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success - no error
    } on FirebaseAuthException catch (e) {
      // Return user-friendly error message
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Login existing user with email and password
  // Returns null on success, error message on failure
  Future<String?> loginWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in user
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null; // Success - no error
    } on FirebaseAuthException catch (e) {
      // Return user-friendly error message
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Logout current user
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Send password reset email
  Future<String?> resetPassword(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null; // Success
    } on FirebaseAuthException catch (e) {
      return _getErrorMessage(e.code);
    } catch (e) {
      return 'An unexpected error occurred. Please try again.';
    }
  }

  // Convert Firebase error codes to user-friendly messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }
}
