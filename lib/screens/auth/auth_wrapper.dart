import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
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
import '../navigation/main_navigation.dart';

/// AuthWrapper - Decides whether to show login or home based on auth state.
/// On WEB: Uses Supabase auth stream (existing behavior).
/// On MOBILE: Checks for guest mode via SharedPreferences, shows WelcomeScreen on first launch.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingGuest = true;
  bool _isGuestMode = false;
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.passwordRecovery) {
        _handlePasswordRecovery();
      }
    });
    if (!kIsWeb) {
      _checkGuestMode();
    } else {
      _isCheckingGuest = false;
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handlePasswordRecovery() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingNoteId = prefs.getString('pending_unlock_note_id');
    if (pendingNoteId != null) {
      await prefs.remove('pending_unlock_note_id');
      try {
        final authService = AuthService();
        final notesService = NotesService(authService);
        
        // Remove lock first
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
                    'lockPassword': hasPassword ? passwordController.text : null,
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    showSuccessSnackBar(context, hasPassword
                        ? 'New note password set successfully!'
                        : 'Note will remain unlocked.');
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

  Future<void> _checkGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    final isGuest = prefs.getBool('is_guest_mode') ?? false;

    if (mounted) {
      setState(() {
        _isGuestMode = isGuest;
        _isCheckingGuest = !hasSeenOnboarding && !isGuest;
      });
    }

    // If user has seen onboarding and chose guest, go straight to main
    // If user has an active session, go to main
    // If first launch, show welcome screen (_isCheckingGuest stays true)
    if (hasSeenOnboarding) {
      setState(() => _isCheckingGuest = false);
    }
  }

  Future<void> _enterGuestMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_seen_onboarding', true);
    await prefs.setBool('is_guest_mode', true);
    if (mounted) {
      setState(() {
        _isGuestMode = true;
        _isCheckingGuest = false;
      });
    }
  }

  void _goToLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<SupabaseAuthService>(
      context,
      listen: false,
    );

    return StreamBuilder<AuthState>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Use currentSession for immediate synchronous state to avoid waiting delays
        final session = Supabase.instance.client.auth.currentSession;
        
        if (session != null) {
          // Web-only: Check for a pending plan from OAuth signup flow
          if (kIsWeb) {
            // Clean URL query parameters to avoid loops/stuck codes
            WidgetsBinding.instance.addPostFrameCallback((_) {
              platform.replaceHistoryState('/app');
            });

            final pendingPlan = platform.getLocalStorageValue('pending_plan');
            final pendingPeriod = platform.getLocalStorageValue('pending_period');
            if (pendingPlan != null && pendingPlan.isNotEmpty) {
              platform.removeLocalStorageValue('pending_plan');
              platform.removeLocalStorageValue('pending_period');
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final origin = platform.getLocationOrigin();
                platform.setLocationHref('$origin/checkout?plan=$pendingPlan&period=${pendingPeriod ?? 'monthly'}');
              });
            }
          }
          return const MainNavigation();
        }

        // Show loading spinner only on Web when waiting. On mobile we show WelcomeScreen immediately.
        if (snapshot.connectionState == ConnectionState.waiting && session == null && kIsWeb) {
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

        // Mobile fallback logic
        if (!kIsWeb) {
          if (_isCheckingGuest) {
            return WelcomeScreen(
              onLoginTap: _goToLogin,
              onSignUpTap: _goToLogin,
              onGoogleSignIn: () async {
                await authService.signInWithGoogle();
              },
              onGuestContinue: _enterGuestMode,
            );
          }
          return const MainNavigation();
        }

        // Web fallback logic
        return const LoginScreen();
      },
    );
  }
}
