import 'package:supabase_flutter/supabase_flutter.dart';
import 'base_service.dart';

/// Service for authentication operations
class AuthService extends BaseService {
  /// Signs in a user with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  /// Signs up a new user with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    return await supabase.auth.signUp(
      email: email,
      password: password,
    );
  }

  /// Signs out the current user
  Future<void> signOut() async {
    await supabase.auth.signOut();
  }

  /// Gets the current authenticated user
  User? get currentUser => supabase.auth.currentUser;

  /// Checks if a user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  /// Gets a stream of auth state changes
  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;

  /// Sends a password reset email
  Future<void> resetPassword(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  /// Updates the user's password
  Future<UserResponse> updatePassword(String newPassword) async {
    return await supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }

  /// Updates the user's email
  Future<UserResponse> updateEmail(String newEmail) async {
    return await supabase.auth.updateUser(
      UserAttributes(email: newEmail),
    );
  }

  /// Refreshes the current session
  Future<AuthResponse> refreshSession() async {
    return await supabase.auth.refreshSession();
  }
}
