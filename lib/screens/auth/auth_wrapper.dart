import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart' show closeInAppWebView;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/platform_helper.dart' as platform;
import '../../config/theme.dart';
import '../../utils/ui_helper.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_auth_service.dart';
import '../../services/notes_service.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import '../tutorial/tutorial_screen.dart';
import '../navigation/main_navigation.dart';

/// Mobile-only phases for the onboarding state machine.
enum _MobilePhase { loading, welcome, tutorial, app }

/// AuthWrapper — Decides what to show based on auth state and onboarding progress.
///
/// WEB:    Uses Supabase auth stream. Shows LoginScreen or MainNavigation.
///         Completely unchanged from previous behavior.
///
/// MOBILE: Clean state machine (first launch only):
///   1. loading   → Check SharedPreferences + session
///   2. welcome   → WelcomeScreen (Google sign-in / email login / guest)
///   3. tutorial  → TutorialScreen (6 swipeable feature pages)
///   4. app       → MainNavigation
///
///   Subsequent launches skip straight to [app].
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  _MobilePhase _phase = _MobilePhase.loading;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen(_onAuthEvent);

    if (!kIsWeb) {
      _initMobile();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // Auth event handler
  // ─────────────────────────────────────────────────────────────

  void _onAuthEvent(AuthState data) {
    final event = data.event;

    // Mobile: OAuth deep-link returned while WelcomeScreen is visible
    if (!kIsWeb && event == AuthChangeEvent.signedIn) {
      closeInAppWebView();
      // Clear guest mode flag on sign-in
      SharedPreferences.getInstance().then((prefs) {
        prefs.remove('is_guest_mode');
      });
      if (_phase == _MobilePhase.welcome) {
        _advanceToTutorial();
      }
      return;
    }

    // Mobile: Reactively transition back to welcome phase when signed out
    if (!kIsWeb && event == AuthChangeEvent.signedOut) {
      if (mounted) {
        setState(() {
          _phase = _MobilePhase.welcome;
        });
      }
      return;
    }

    // Both platforms: password recovery flow
    if (event == AuthChangeEvent.passwordRecovery) {
      _handlePasswordRecovery();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Mobile init — decide which phase to start in
  // ─────────────────────────────────────────────────────────────

  Future<void> _initMobile() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedOnboarding =
        prefs.getBool('has_seen_onboarding') ?? false;
    final session = Supabase.instance.client.auth.currentSession;

    if (!mounted) return;

    if (hasCompletedOnboarding) {
      // Returning user → straight to app
      setState(() => _phase = _MobilePhase.app);
    } else if (session != null) {
      // Has a session but never finished onboarding
      // (e.g. redirected here from LoginScreen after email login)
      setState(() => _phase = _MobilePhase.tutorial);
    } else {
      // First launch, no session → show welcome
      setState(() => _phase = _MobilePhase.welcome);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Phase transitions
  // ─────────────────────────────────────────────────────────────

  void _advanceToTutorial() {
    if (mounted) {
      setState(() => _phase = _MobilePhase.tutorial);
    }
  }

  Future<void> _onTutorialComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    if (mounted) {
      setState(() => _phase = _MobilePhase.app);
    }
  }

  // ─────────────────────────────────────────────────────────────
  // build()
  // ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // ── WEB: existing behavior, completely untouched ──────────
    if (kIsWeb) {
      return _buildWebFlow(context);
    }

    // ── MOBILE: state machine ────────────────────────────────
    switch (_phase) {
      case _MobilePhase.loading:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );

      case _MobilePhase.welcome:
        return _buildWelcome(context);

      case _MobilePhase.tutorial:
        return TutorialScreen(
          isOnboarding: true,
          onComplete: _onTutorialComplete,
        );

      case _MobilePhase.app:
        return const MainNavigation();
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Mobile: WelcomeScreen with all callbacks wired up
  // ─────────────────────────────────────────────────────────────

  Widget _buildWelcome(BuildContext context) {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);

    return WelcomeScreen(
      onLoginTap: () {
        // Push LoginScreen (not replace) so AuthWrapper stays alive
        // and the auth listener can detect a signedIn event.
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      },
      onSignUpTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const LoginScreen(showRegisterDialog: true),
          ),
        );
      },
      onGoogleSignIn: () async {
        await authService.signInWithGoogle();
        // The signedIn event in _onAuthEvent will call _advanceToTutorial
      },
      onGuestContinue: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest_mode', true);
        _advanceToTutorial();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Web: existing StreamBuilder flow (unchanged)
  // ─────────────────────────────────────────────────────────────

  Widget _buildWebFlow(BuildContext context) {
    final authService =
        Provider.of<SupabaseAuthService>(context, listen: false);

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          // Clean URL query parameters to avoid loops/stuck codes
          WidgetsBinding.instance.addPostFrameCallback((_) {
            platform.replaceHistoryState('/app');
          });

          final pendingPlan = platform.getLocalStorageValue('pending_plan');
          final pendingPeriod =
              platform.getLocalStorageValue('pending_period');
          if (pendingPlan != null && pendingPlan.isNotEmpty) {
            platform.removeLocalStorageValue('pending_plan');
            platform.removeLocalStorageValue('pending_period');
            WidgetsBinding.instance.addPostFrameCallback((_) {
              final origin = platform.getLocationOrigin();
              platform.setLocationHref(
                '$origin/checkout?plan=$pendingPlan&period=${pendingPeriod ?? 'monthly'}',
              );
            });
          }
          return const MainNavigation();
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(
                    'Loading...',
                    style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey
                          : AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return const LoginScreen();
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Password recovery (shared between web and mobile)
  // ─────────────────────────────────────────────────────────────

  Future<void> _handlePasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingNoteId = prefs.getString('pending_unlock_note_id');
    if (pendingNoteId != null) {
      await prefs.remove('pending_unlock_note_id');
      try {
        final authService = AuthService();
        final notesService = NotesService(authService);

        await notesService.updateNote(pendingNoteId, {
          'isLocked': false,
          'lockPassword': null,
        });

        if (mounted) {
          _showNewNoteLockPasswordDialog(pendingNoteId);
        }
      } catch (e) {
        debugPrint('Error unlocking note: $e');
      }
    }
  }

  void _showNewNoteLockPasswordDialog(String noteId) {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Set Note Password'),
          ],
        ),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Identity verified! The note lock was successfully removed. '
                  'Set a new note-specific password below, or leave it blank to keep the note unlocked.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'New Note Password',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) {
                    if (value != null && value.isNotEmpty && value.length < 4) {
                      return 'Password must be at least 4 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    hintText: 'Confirm Note Password',
                    prefixIcon: Icon(Icons.key),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Unlocked'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState?.validate() == true) {
                try {
                  final hasPassword = passwordController.text.isNotEmpty;
                  final authService = AuthService();
                  final notesService = NotesService(authService);

                  await notesService.updateNote(noteId, {
                    'isLocked': hasPassword,
                    'lockPassword':
                        hasPassword ? passwordController.text : null,
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    showSuccessSnackBar(
                      context,
                      hasPassword
                          ? 'New note password set successfully!'
                          : 'Note will remain unlocked.',
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showErrorSnackBar(context, 'Failed to update note: $e');
                  }
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
