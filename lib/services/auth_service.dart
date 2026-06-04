// Legacy AuthService Compatibility Layer
// This provides the old AuthService interface using Supabase under the hood
// for backward compatibility during migration

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

/// Legacy AuthService wrapper around Supabase Auth
/// This allows existing code to continue working during migration
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Get current user email
  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// Get current user display name
  String? get currentUserDisplayName =>
      _client.auth.currentUser?.userMetadata?['full_name'] ??
      _client.auth.currentUser?.userMetadata?['name'];

  /// Get current user photo URL
  String? get currentUserPhotoUrl =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] ??
      _client.auth.currentUser?.userMetadata?['picture'];

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Stream of auth state changes (returns User? for compatibility)
  Stream<User?> get authStateChanges =>
      _client.auth.onAuthStateChange.map((state) => state.session?.user);

  /// Get current user (Supabase User type)
  User? get currentUser => _client.auth.currentUser;

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      debugPrint('[INFO] Email sign-in successful: $email');
      return response;
    } catch (e, stack) {
      debugPrint('[ERROR] Email sign-in failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Create new user with email and password
  Future<AuthResponse> signUp(String email, String password) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      debugPrint('[INFO] Sign-up successful: $email');
      return response;
    } catch (e, stack) {
      debugPrint('[ERROR] Sign-up failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<void> signInWithGoogle() async {
    try {
      debugPrint('[INFO] Starting Google sign-in (web: $kIsWeb)');
      
      if (kIsWeb) {
        final redirectUrl = '${Uri.base.origin}/app';
        debugPrint('[INFO] Redirect URL: $redirectUrl');
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: redirectUrl,
        );
      } else {
        // Use Chrome Custom Tab (inAppBrowserView) instead of external Chrome.
        // This auto-closes when the deep link redirect fires.
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.inksync://login-callback/',
          authScreenLaunchMode: LaunchMode.inAppBrowserView,
        );
      }
      debugPrint('[INFO] Google sign-in initiated. Redirecting...');
    } catch (e, stack) {
      debugPrint('[ERROR] Google sign-in failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      debugPrint('[INFO] User signed out');
    } catch (e, stack) {
      debugPrint('[ERROR] Sign-out failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      debugPrint('[INFO] Password reset email sent to: $email');
    } catch (e, stack) {
      debugPrint('[ERROR] Password reset failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Get user data as map
  Map<String, dynamic>? getUserData() {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    return {
      'email': user.email,
      'uid': user.id,
      'displayName': currentUserDisplayName,
      'photoURL': currentUserPhotoUrl,
    };
  }
}
