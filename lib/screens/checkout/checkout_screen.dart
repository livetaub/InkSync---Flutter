// ignore_for_file: avoid_web_libraries_in_flutter
// This screen is WEB-ONLY — uses Stripe.js, dart:html, dart:js.
// It is never navigated to on mobile platforms.
import 'dart:convert';
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'dart:js_util' as js_util;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/paywall_variant.dart';
import '../../services/paywall_service.dart';
import '../../utils/platform_helper.dart' as platform;
import '../../config/theme.dart';
import '../../config/stripe_config.dart';

/// Checkout Screen — Native Stripe Elements Integration
///
/// Embeds a real Stripe card input directly inside the InkSync UI.
/// The user never leaves inksyncnote.com. Card numbers are tokenized
/// by Stripe.js in the browser and never touch our servers.
class CheckoutScreen extends StatefulWidget {
  final String plan;   // 'premium'
  final String period; // 'monthly' or 'yearly'

  const CheckoutScreen({
    super.key,
    required this.plan,
    required this.period,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  bool _isLoading = false;
  bool _stripeReady = false;
  String? _error;
  String? _cardError;
  final String _viewId = 'stripe-card-element-${DateTime.now().millisecondsSinceEpoch}';

  // Pricing from variant
  PaywallVariant? _variant;

  @override
  void initState() {
    super.initState();
    _fetchPricing();
    _registerStripeView();
  }

  /// Register the HtmlElementView for the Stripe Card Element
  void _registerStripeView() {
    // Create a styled container for the Stripe card input
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(_viewId, (int viewId) {
      final container = html.DivElement()
        ..id = 'stripe-card-container-$viewId'
        ..style.width = '100%'
        ..style.padding = '14px 16px'
        ..style.border = '1.5px solid #E2E8F0'
        ..style.borderRadius = '12px'
        ..style.backgroundColor = '#F8FAFC'
        ..style.transition = 'border-color 0.2s ease'
        ..style.boxSizing = 'border-box';

      // Focus styling
      container.onFocus.listen((_) {
        container.style.borderColor = '#10B981';
        container.style.boxShadow = '0 0 0 3px rgba(16, 185, 129, 0.1)';
      });

      // Mount Stripe Elements after the container is in the DOM
      Future.delayed(const Duration(milliseconds: 300), () {
        try {
          final result = js_util.callMethod(
            html.window,
            'initStripeElements',
            [StripeConfig.publishableKey, container.id],
          );
          if (result == 'ok') {
            if (mounted) setState(() => _stripeReady = true);
          }
        } catch (e) {
          debugPrint('Error initializing Stripe Elements: $e');
        }
      });

      return container;
    });
  }

  /// Fetch pricing from the user's assigned paywall variant
  Future<void> _fetchPricing() async {
    try {
      final variant = await PaywallService.instance.getVariant();
      if (mounted) setState(() => _variant = variant);
    } catch (e) {
      debugPrint('Error fetching variant pricing: $e');
    }
  }

  /// Submit payment
  Future<void> _submitPayment() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _cardError = null;
    });

    try {
      final isComplete = js_util.callMethod(html.window, 'isStripeCardComplete', []);
      if (isComplete != true) {
        setState(() {
          _cardError = 'Please enter your complete card details.';
          _isLoading = false;
        });
        return;
      }

      final userEmail = Supabase.instance.client.auth.currentUser?.email ?? '';
      final res = js_util.callMethod(
        html.window,
        'createStripePaymentMethod',
        [userEmail, ''],
      );

      String resultJson;
      if (res == null) {
        resultJson = '{"error": "Stripe bridge returned null"}';
      } else if (res is! String) {
        final promiseResult = await js_util.promiseToFuture(res);
        resultJson = promiseResult.toString();
      } else {
        resultJson = res;
      }

      final result = jsonDecode(resultJson);
      if (result['error'] != null) {
        setState(() {
          _cardError = result['error'];
          _isLoading = false;
        });
        return;
      }

      final paymentMethodId = result['paymentMethodId'] as String;

      final response = await Supabase.instance.client.functions.invoke(
        'create-subscription',
        body: {
          'paymentMethodId': paymentMethodId,
          'plan': widget.plan,
          'period': widget.period,
          'variant_id': _variant?.id,
        },
      );

      if (response.status != 200) {
        final errorMsg = response.data?['error'] ?? 'Payment failed. Please try again.';
        setState(() {
          _error = errorMsg.toString();
          _isLoading = false;
        });
        return;
      }

      final data = response.data;
      final status = data['status'] as String?;

      if (status == 'active') {
        if (mounted) {
          final origin = platform.getLocationOrigin();
          platform.setLocationHref('$origin/checkout-success');
        }
      } else if (status == 'requires_action') {
        final clientSecret = data['clientSecret'] as String;
        final res = js_util.callMethod(
          html.window,
          'confirmStripePayment',
          [clientSecret],
        );
        if (res != null && res is! String) {
          await js_util.promiseToFuture(res);
        }
        
        if (mounted) {
          final origin = html.window.location.origin;
          html.window.location.href = '$origin/checkout-success';
        }
      } else {
        setState(() {
          _error = data['error'] ?? 'Payment could not be processed.';
          _isLoading = false;
        });
      }
    } on FunctionException catch (e) {
      debugPrint('Supabase FunctionException caught during checkout: status=${e.status}, details=${e.details}');
      String displayError = 'Payment failed. Please try again.';
      if (e.details is Map) {
        displayError = e.details['error']?.toString() ?? displayError;
      } else if (e.details is String) {
        try {
          final decoded = jsonDecode(e.details as String);
          displayError = decoded['error']?.toString() ?? displayError;
        } catch (_) {
          displayError = e.details.toString();
        }
      } else if (e.reasonPhrase != null) {
        displayError = e.reasonPhrase!;
      }
      setState(() {
        _error = displayError;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Exception caught during checkout: $e');
      debugPrintStack(stackTrace: stackTrace);
      setState(() {
        _error = 'Checkout Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final planLabel = 'Premium';
    final tier = _variant?.getTier(widget.plan);
    final price = tier != null
        ? (widget.period == 'yearly' ? tier.priceYearly : tier.priceMonthly)
        : null;
    final periodLabel = widget.period == 'yearly' ? '/year' : '/month';

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FAFC), Color(0xFFECFDF5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 40,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Header ───────────────────────────────
                    Center(
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10B981), Color(0xFF059669)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF10B981).withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: const Icon(Icons.diamond_rounded, size: 28, color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Text(
                        'Upgrade to $planLabel',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        price != null
                            ? 'You\'ll be charged \$$price$periodLabel'
                            : 'Loading pricing...',
                        style: const TextStyle(fontSize: 15, color: Color(0xFF64748B)),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Plan Summary ────────────────────────
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'InkSync $planLabel — ${widget.period == 'yearly' ? 'Annual' : 'Monthly'}',
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cancel anytime • Instant access',
                                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                                ),
                              ],
                            ),
                          ),
                          if (price != null)
                            Text(
                              '\$$price',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Card Input Label ─────────────────────
                    const Text(
                      'Payment details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Stripe Card Element (embedded) ───────
                    SizedBox(
                      height: 54,
                      child: HtmlElementView(viewType: _viewId),
                    ),

                    // Card error
                    if (_cardError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _cardError!,
                        style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 20),

                    // ── Error Banner ─────────────────────────
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(14),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFFECACA)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Subscribe Button ─────────────────────
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submitPayment,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          disabledBackgroundColor: AppTheme.primaryColor.withValues(alpha: 0.6),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                price != null
                                    ? 'Subscribe — \$$price$periodLabel'
                                    : 'Subscribe',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Security Badge ───────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 14, color: Colors.grey.shade400),
                          const SizedBox(width: 6),
                          Text(
                            'Secured by Stripe • 256-bit encryption',
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Back Link ────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: () {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                            platform.setLocationHref('https://inksyncnote.com/pricing');
                          }
                        },
                        child: const Text(
                          '← Back to pricing',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Checkout Success Screen
///
/// Displayed after the user successfully completes payment.
/// Shows animated confirmation and auto-redirects to the app.
class CheckoutSuccessScreen extends StatefulWidget {
  const CheckoutSuccessScreen({super.key});

  @override
  State<CheckoutSuccessScreen> createState() => _CheckoutSuccessScreenState();
}

class _CheckoutSuccessScreenState extends State<CheckoutSuccessScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _checkAnim;

  @override
  void initState() {
    super.initState();
    _checkAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Auto-redirect to the app after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        final origin = platform.getLocationOrigin();
        platform.setLocationHref('$origin/app');
      }
    });
  }

  @override
  void dispose() {
    _checkAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0FDF4), Color(0xFFECFDF5)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated checkmark
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _checkAnim,
                      curve: Curves.elasticOut,
                    ),
                    child: Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.4),
                            blurRadius: 28,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, size: 44, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Welcome to InkSync Pro! 🎉',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your subscription is now active. All premium features are unlocked and ready to use.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: Color(0xFF64748B), height: 1.6),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final origin = platform.getLocationOrigin();
                        platform.setLocationHref('$origin/app');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start Using InkSync →',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Redirecting automatically...',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
