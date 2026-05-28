import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../utils/ui_helper.dart';

/// LoginPromptModal — Reusable bottom sheet shown when a guest user
/// attempts to access a feature requiring authentication (Share, Sync, etc).
class LoginPromptModal {
  /// Show the modal. Returns true if user chose to log in, false otherwise.
  static Future<bool> show(
    BuildContext context, {
    required String featureName,
    required VoidCallback onLoginTap,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    final result = await showAdaptiveModal<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDesktop ? null : Colors.transparent,
      child: Builder(
        builder: (ctx) => Container(
          padding: EdgeInsets.only(
            left: 28,
            right: 28,
            top: 28,
            bottom: isDesktop ? 28 : (MediaQuery.of(ctx).padding.bottom + 28),
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: isDesktop ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                // Drag handle
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 28),
              ],

              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.account_circle_rounded,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Login or Create an Account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                '$featureName requires an account. Sign in to unlock cross-device sync, collaboration, and more.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: isDark ? Colors.white60 : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Login / Sign Up button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx, true);
                    onLoginTap();
                  },
                  icon: const Icon(Icons.login_rounded, size: 20),
                  label: const Text(
                    'Login or Sign Up',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Not now
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(
                  'Not Now',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return result ?? false;
  }
}
