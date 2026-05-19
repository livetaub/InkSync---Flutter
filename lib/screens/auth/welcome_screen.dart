import 'package:flutter/material.dart';
import '../../config/theme.dart';

/// WelcomeScreen — First screen shown on mobile app install.
/// Offers Login/Sign Up with a "Continue as Guest" option.
/// Premium, polished design matching the InkSync brand.
class WelcomeScreen extends StatefulWidget {
  final VoidCallback onLoginTap;
  final VoidCallback onSignUpTap;
  final VoidCallback onGoogleSignIn;
  final VoidCallback onGuestContinue;

  const WelcomeScreen({
    super.key,
    required this.onLoginTap,
    required this.onSignUpTap,
    required this.onGoogleSignIn,
    required this.onGuestContinue,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _showGuestDisclaimer() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: AppTheme.primaryColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Text(
                'Heads Up',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Body
              Text(
                'Notes created as a guest are saved securely on this device, but won\'t sync across your other devices until you create an account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.55,
                  color: isDark ? Colors.white70 : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),

              // Got it button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    widget.onGuestContinue();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Got It, Continue',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Go back
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Go Back',
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SlideTransition(
            position: _slideUp,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                children: [
                  SizedBox(height: screenHeight * 0.08),

                  // Logo & Branding
                  _buildBranding(isDark),

                  const Spacer(),

                  // Auth Buttons
                  _buildAuthSection(isDark),

                  const SizedBox(height: 20),

                  // Skip button
                  _buildSkipButton(isDark),

                  SizedBox(height: screenHeight * 0.05),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBranding(bool isDark) {
    return Column(
      children: [
        // App Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF05D07D), Color(0xFF00B86B)],
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.edit_note_rounded,
            color: Colors.white,
            size: 40,
          ),
        ),
        const SizedBox(height: 28),

        // App Name
        Text(
          'InkSync',
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Tagline
        Text(
          'Your notes, everywhere.\nSecure. Synced. Simple.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: isDark ? Colors.white60 : AppTheme.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthSection(bool isDark) {
    return Column(
      children: [
        // Google Sign In
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: widget.onGoogleSignIn,
            icon: Image.network(
              'https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
              width: 20,
              height: 20,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, size: 24),
            ),
            label: const Text(
              'Continue with Google',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white : AppTheme.textPrimary,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Email Sign Up
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: widget.onSignUpTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Create Account',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Log In
        SizedBox(
          width: double.infinity,
          height: 52,
          child: TextButton(
            onPressed: widget.onLoginTap,
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text(
              'Already have an account? Log In',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSkipButton(bool isDark) {
    return TextButton(
      onPressed: _showGuestDisclaimer,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Sign up later',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.arrow_forward_ios_rounded,
            size: 12,
            color: isDark ? Colors.white38 : AppTheme.textMuted,
          ),
        ],
      ),
    );
  }
}
