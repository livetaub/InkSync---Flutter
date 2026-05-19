import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/theme.dart';
import '../../config/stripe_config.dart';

/// Android Checkout Screen — Full-screen WebView wrapping Stripe Checkout.
///
/// Loads a Stripe-hosted checkout session inside an in-app WebView
/// so the user never sees browser chrome — it feels fully native.
///
/// Flow:
///   1. Calls `create-checkout-session` Edge Function → gets a Stripe Checkout URL
///   2. WebView loads that URL
///   3. On success redirect → intercepts and pops with success
///   4. On cancel redirect → intercepts and pops
class AndroidCheckoutScreen extends StatefulWidget {
  final String planId;    // e.g., 'premium_monthly'
  final String period;    // 'monthly' or 'yearly'

  const AndroidCheckoutScreen({
    super.key,
    required this.planId,
    required this.period,
  });

  @override
  State<AndroidCheckoutScreen> createState() => _AndroidCheckoutScreenState();
}

class _AndroidCheckoutScreenState extends State<AndroidCheckoutScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isCreatingSession = true;
  String? _error;
  double _progress = 0;

  /// URLs that signal checkout completion
  static const _successFragment = '/checkout-success';
  static const _cancelFragment = '/pricing';

  @override
  void initState() {
    super.initState();
    _initWebView();
    _createCheckoutSession();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress / 100);
          },
          onNavigationRequest: (request) {
            final url = request.url;

            // Intercept success redirect
            if (url.contains(_successFragment)) {
              _onCheckoutSuccess();
              return NavigationDecision.prevent;
            }

            // Intercept cancel redirect
            if (url.contains(_cancelFragment)) {
              Navigator.pop(context, false);
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('WebView error: ${error.description}');
          },
        ),
      );
  }

  /// Call the Supabase Edge Function to create a Stripe Checkout Session
  Future<void> _createCheckoutSession() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final userEmail = Supabase.instance.client.auth.currentUser?.email;

      if (userId == null) {
        setState(() {
          _error = 'You must be logged in to subscribe.';
          _isCreatingSession = false;
        });
        return;
      }

      // Read the pricing config to get the Stripe product ID
      final pricingConfig = await Supabase.instance.client
          .from('pricing_config')
          .select()
          .eq('plan_id', '${widget.planId}_${widget.period}')
          .maybeSingle();

      if (pricingConfig == null) {
        // Fallback: try without period suffix
        final fallback = await Supabase.instance.client
            .from('pricing_config')
            .select()
            .eq('plan_id', widget.planId)
            .maybeSingle();

        if (fallback == null) {
          setState(() {
            _error = 'Plan not found. Please try again later.';
            _isCreatingSession = false;
          });
          return;
        }
      }

      // Create the Stripe Checkout Session via Edge Function
      final response = await Supabase.instance.client.functions.invoke(
        'create-checkout-session',
        body: {
          'plan': widget.planId,
          'period': widget.period,
          'success_url': '${StripeConfig.successUrl}',
          'cancel_url': '${StripeConfig.cancelUrl}',
          if (userEmail != null) 'email': userEmail,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Failed to create checkout session.';
        setState(() {
          _error = errorMsg.toString();
          _isCreatingSession = false;
        });
        return;
      }

      final checkoutUrl = response.data?['url'] as String?;
      if (checkoutUrl == null || checkoutUrl.isEmpty) {
        setState(() {
          _error = 'Invalid checkout session. Please try again.';
          _isCreatingSession = false;
        });
        return;
      }

      // Load the Stripe Checkout page in the WebView
      await _controller.loadRequest(Uri.parse(checkoutUrl));

      if (mounted) {
        setState(() => _isCreatingSession = false);
      }
    } catch (e) {
      debugPrint('Error creating checkout session: $e');
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Please try again.';
          _isCreatingSession = false;
        });
      }
    }
  }

  /// Called when the WebView hits the success URL
  void _onCheckoutSuccess() {
    // Update local premium status immediately
    _updatePremiumStatus();

    // Show success and pop
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _SuccessDialog(
          onDismiss: () {
            Navigator.pop(ctx);           // Close dialog
            Navigator.pop(context, true); // Return success to caller
          },
        ),
      );
    }
  }

  /// Update Supabase user_settings after successful checkout
  Future<void> _updatePremiumStatus() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('user_settings')
          .update({'is_premium': true})
          .eq('user_id', userId);

      await Supabase.instance.client
          .from('profiles')
          .update({'account_type': widget.planId})
          .eq('id', userId);
    } catch (e) {
      debugPrint('Error updating premium status: $e');
      // Non-critical — Stripe webhook will handle this
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────
            _buildHeader(isDark),

            // ─── Progress bar ────────────────────────────
            if (_isLoading || _isCreatingSession)
              LinearProgressIndicator(
                value: _isCreatingSession ? null : _progress,
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.grey.shade100,
                valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
                minHeight: 2,
              ),

            // ─── Content ────────────────────────────────
            Expanded(
              child: _error != null
                  ? _buildErrorState(isDark)
                  : _isCreatingSession
                      ? _buildCreatingState(isDark)
                      : WebViewWidget(controller: _controller),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context, false),
            icon: Icon(
              Icons.close_rounded,
              size: 22,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.lock_rounded,
            size: 14,
            color: AppTheme.primaryColor,
          ),
          const SizedBox(width: 6),
          Text(
            'Secure Checkout',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const Spacer(),
          // Stripe badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.shield_rounded,
                    size: 12,
                    color: isDark ? Colors.white38 : const Color(0xFF64748B)),
                const SizedBox(width: 4),
                Text(
                  'Stripe',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white38 : const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildCreatingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 20),
          Text(
            'Preparing checkout...',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFDC2626), size: 36),
            ),
            const SizedBox(height: 20),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Go Back',
                    style: TextStyle(
                      color: isDark ? Colors.white54 : AppTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _error = null;
                      _isCreatingSession = true;
                    });
                    _createCheckoutSession();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── SUCCESS DIALOG ──────────────────────────────────────────────────

class _SuccessDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  const _SuccessDialog({required this.onDismiss});

  @override
  State<_SuccessDialog> createState() => _SuccessDialogState();
}

class _SuccessDialogState extends State<_SuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 340),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF161B22) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: CurvedAnimation(
                parent: _anim,
                curve: Curves.elasticOut,
              ),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF10B981), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(Icons.check_rounded,
                    size: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Welcome to InkSync Pro! 🎉',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'All premium features are now unlocked.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xFF64748B),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: widget.onDismiss,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Start Using Pro →',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
