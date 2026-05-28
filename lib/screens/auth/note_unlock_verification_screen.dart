import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/theme.dart';
import '../../utils/platform_helper.dart' as platform;
import '../../utils/ui_helper.dart';

/// NoteUnlockVerificationScreen - Opened when a user clicks the note reset password link.
/// Verifies the token and lets the user set a new password or completely unlock the note.
class NoteUnlockVerificationScreen extends StatefulWidget {
  final String token;
  final String noteId;

  const NoteUnlockVerificationScreen({
    super.key,
    required this.token,
    required this.noteId,
  });

  @override
  State<NoteUnlockVerificationScreen> createState() =>
      _NoteUnlockVerificationScreenState();
}

class _NoteUnlockVerificationScreenState
    extends State<NoteUnlockVerificationScreen> {
  bool _isVerifying = true;
  bool _isValidToken = false;
  bool _isSaving = false;
  String? _errorMessage;

  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkTokenValidity();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkTokenValidity() async {
    if (widget.token.isEmpty || widget.noteId.isEmpty) {
      setState(() {
        _isVerifying = false;
        _isValidToken = false;
        _errorMessage = 'Invalid link parameters.';
      });
      return;
    }

    try {
      final bool isValid = await Supabase.instance.client.rpc(
        'check_note_unlock_token',
        params: {
          'p_note_id': widget.noteId,
          'p_token': widget.token,
        },
      );

      setState(() {
        _isVerifying = false;
        _isValidToken = isValid;
        if (!isValid) {
          _errorMessage = 'This link is invalid or has expired.';
        }
      });
    } catch (e) {
      setState(() {
        _isVerifying = false;
        _isValidToken = false;
        _errorMessage = 'Failed to verify link: $e';
      });
    }
  }

  Future<void> _submit(String? newPassword) async {
    setState(() => _isSaving = true);

    try {
      final bool success = await Supabase.instance.client.rpc(
        'verify_note_unlock',
        params: {
          'p_note_id': widget.noteId,
          'p_token': widget.token,
          'p_new_password': newPassword,
        },
      );

      if (success) {
        if (mounted) {
          showSuccessSnackBar(
            context,
            newPassword == null
                ? 'Note unlocked successfully!'
                : 'New note password set successfully!',
          );
          // Redirect to app
          final origin = platform.getLocationOrigin();
          platform.setLocationHref('$origin/app');
        }
      } else {
        setState(() {
          _isSaving = false;
          _errorMessage = 'Verification failed. The token may have expired.';
        });
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF161B22) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
                width: 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo Icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.lock_open_rounded,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),

                // App Branding
                Text(
                  'InkSync',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure Note Unlock',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 32),

                // Body content based on state
                if (_isVerifying)
                  _buildVerifyingState(isDark)
                else if (_errorMessage != null && !_isValidToken)
                  _buildErrorState(isDark)
                else
                  _buildFormState(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVerifyingState(bool isDark) {
    return Column(
      children: [
        const SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Verifying unlock link...',
          style: TextStyle(
            fontSize: 14.5,
            color: isDark ? Colors.white70 : AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Column(
      children: [
        Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 48),
        const SizedBox(height: 16),
        Text(
          _errorMessage ?? 'Verification Failed',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () {
              final origin = platform.getLocationOrigin();
              platform.setLocationHref('$origin/app');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
              foregroundColor: isDark ? Colors.white70 : AppTheme.textPrimary,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Back to InkSync'),
          ),
        ),
      ],
    );
  }

  Widget _buildFormState(bool isDark) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your identity has been verified. You can now set a new password for this note, or completely remove the lock.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),

          // New Password field
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'New password (min 4 chars)',
              prefixIcon: Icon(Icons.lock_rounded, size: 20),
            ),
            style: const TextStyle(fontSize: 15),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter a password';
              }
              if (value.length < 4) {
                return 'Password must be at least 4 characters';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),

          // Confirm Password field
          TextFormField(
            controller: _confirmPasswordController,
            obscureText: true,
            decoration: const InputDecoration(
              hintText: 'Confirm new password',
              prefixIcon: Icon(Icons.lock_clock_rounded, size: 20),
            ),
            style: const TextStyle(fontSize: 15),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Save Password Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isSaving
                  ? null
                  : () {
                      if (_formKey.currentState!.validate()) {
                        _submit(_passwordController.text);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Text(
                      'Save Password & Open Note',
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // Remove Lock Completely Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: _isSaving ? null : () => _submit(null),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                side: BorderSide(color: Colors.red.shade400.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Unlock Completely (Remove Lock)',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
