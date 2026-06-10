import 'dart:io' show Platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;
import 'package:google_sign_in/google_sign_in.dart';
import '../config/supabase_config.dart';

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
  Future<AuthResponse?> signInWithGoogle() async {
    try {
      debugPrint('[INFO] Starting Google sign-in (web: $kIsWeb)');

      if (!kIsWeb && SupabaseConfig.googleWebClientId.isNotEmpty) {
        debugPrint('[INFO] Starting Native Google sign-in...');
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: Platform.isIOS ? SupabaseConfig.googleIosClientId : null,
          serverClientId: SupabaseConfig.googleWebClientId,
        );
        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          debugPrint('[INFO] Native Google sign-in cancelled by user');
          return null;
        }
        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;

        if (idToken == null) {
          throw Exception('Failed to obtain Google ID Token.');
        }

        final response = await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        debugPrint('[INFO] Native Google sign-in completed successfully');
        return response;
      }

      if (kIsWeb) {
        // For web, use OAuth redirect with explicit callback URL
        // This ensures we return to the same origin after OAuth
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: '${Uri.base.origin}/app',
        );
        // Note: On web, this redirects the page. The auth state will be
        // captured when the page reloads via Supabase.initialize()
        return null;
      } else {
        // For mobile, use Chrome Custom Tab (inAppBrowserView) instead of
        // external Chrome. This auto-closes when the deep link redirect fires,
        // so the user doesn't have a stale Chrome tab left in the background.
        await _client.auth.signInWithOAuth(
          OAuthProvider.google,
          redirectTo: 'io.supabase.inksync://login-callback/',
          authScreenLaunchMode: LaunchMode.inAppBrowserView,
        );
        debugPrint('[INFO] Google sign-in initiated');
        return null; // OAuth redirects, so no immediate response
      }
    } catch (e, stack) {
      debugPrint('[ERROR] Google sign-in failed: $e\nStack: $stack');
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        final GoogleSignIn googleSignIn = GoogleSignIn(
          clientId: Platform.isIOS ? SupabaseConfig.googleIosClientId : null,
          serverClientId: SupabaseConfig.googleWebClientId,
        );
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
          debugPrint('[INFO] Native Google sign-out successful');
        }
      }
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
      debugPrint('[INFO] Profile updated');
    } catch (e, stack) {
      debugPrint('[ERROR] Profile update failed: $e\nStack: $stack');
      rethrow;
    }
  }
}
