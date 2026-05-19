import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'debug_service.dart';

/// Supabase Authentication Service
/// Replaces Firebase Auth with same interface for easy migration
class SupabaseAuthService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current user
  User? get currentUser => _client.auth.currentUser;

  /// Get current user email
  String? get currentUserEmail => _client.auth.currentUser?.email;

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Get current user display name (from user_metadata)
  String? get currentUserDisplayName =>
      _client.auth.currentUser?.userMetadata?['full_name'] ??
      _client.auth.currentUser?.userMetadata?['name'];

  /// Get current user photo URL (from user_metadata)
  String? get currentUserPhotoUrl =>
      _client.auth.currentUser?.userMetadata?['avatar_url'] ??
      _client.auth.currentUser?.userMetadata?['picture'];

  /// Stream of auth state changes
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Check if user is logged in
  bool get isLoggedIn => _client.auth.currentUser != null;

  /// Sign in with email and password
  Future<AuthResponse> signIn(String email, String password) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      DebugService.instance.log('[INFO] Email sign-in successful: $email');
      return response;
    } catch (e, stack) {
      DebugService.instance.log(
        '[ERROR] Email sign-in failed: $e\nStack: $stack',
      );
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
      DebugService.instance.log('[INFO] Sign-up successful: $email');
      return response;
    } catch (e, stack) {
      DebugService.instance.log('[ERROR] Sign-up failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Sign in with Google
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      DebugService.instance.log(
        '[INFO] Starting Google sign-in (web: $kIsWeb)',
      );

      if (kIsWeb) {
        // For web, use OAuth redirect with explicit callback URL
        // This ensures we return to the same origin after OAuth
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: Uri.base.origin,
        );
        // Note: On web, this redirects the page. The auth state will be
        // captured when the page reloads via Supabase.initialize()
        return null;
      } else {
        // For mobile, use OAuth with native sign-in
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.inksync://login-callback/',
        );
        DebugService.instance.log('[INFO] Google sign-in initiated');
        return null; // OAuth redirects, so no immediate response
      }
    } catch (e, stack) {
      DebugService.instance.log(
        '[ERROR] Google sign-in failed: $e\nStack: $stack',
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      DebugService.instance.log('[INFO] User signed out');
    } catch (e, stack) {
      DebugService.instance.log('[ERROR] Sign-out failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Send password reset email
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      DebugService.instance.log('[INFO] Password reset email sent to: $email');
    } catch (e, stack) {
      DebugService.instance.log(
        '[ERROR] Password reset failed: $e\nStack: $stack',
      );
      rethrow;
    }
  }

  /// Get user data as map (compatible with existing code)
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

  /// Update user profile (display name, avatar)
  Future<void> updateProfile({String? displayName, String? photoUrl}) async {
    try {
      await _client.auth.updateUser(
        UserAttributes(
          data: {
            if (displayName != null) 'full_name': displayName,
            if (photoUrl != null) 'avatar_url': photoUrl,
          },
        ),
      );
      DebugService.instance.log('[INFO] Profile updated');
    } catch (e, stack) {
      DebugService.instance.log(
        '[ERROR] Profile update failed: $e\nStack: $stack',
      );
      rethrow;
    }
  }
}
