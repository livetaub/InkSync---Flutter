import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../config/theme.dart';
import '../../services/subscription_service.dart';
import '../checkout/android_checkout_screen.dart';

/// Mobile Paywall Screen — Native iOS/Android subscription UI.
///
/// Pulls pricing from the Supabase `global_pricing` table.
/// Triggers RevenueCat native purchase flow on iOS, or Stripe on Web/Android.
/// Matches the web pricing page's visual design.
class MobilePaywallScreen extends StatefulWidget {
  /// Optional: which feature triggered the paywall (for context messaging)
  final String? featureContext;
  final bool isFromSignup;
  final String? initialPlan;

  const MobilePaywallScreen({
    super.key, 
    this.featureContext,
    this.isFromSignup = false,
    this.initialPlan,
  });

  @override
  State<MobilePaywallScreen> createState() => _MobilePaywallScreenState();
}

class _MobilePaywallScreenState extends State<MobilePaywallScreen>
    with SingleTickerProviderStateMixin {
  bool _isAnnual = false;
  bool _isLoading = true;
  bool _isPurchasing = false;
  bool _isRestoring = false;
  String? _error;

  Map<String, SubscriptionPlan> _plans = {};
  List<Package> _packages = [];

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _loadData();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final subService = SubscriptionService.instance;

      // Fetch pricing from database and RevenueCat packages in parallel
      final results = await Future.wait([
        subService.fetchPricingFromDatabase(),
        subService.getAvailablePackages(),
      ]);

      if (mounted) {
        setState(() {
          _plans = results[0] as Map<String, SubscriptionPlan>;
          _packages = results[1] as List<Package>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Unable to load subscription options.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _purchase(String planId) async {
    if (_isPurchasing) return;
    setState(() {
      _isPurchasing = true;
      _error = null;
    });

    try {
      if (kIsWeb) {
        if (mounted) {
          Navigator.pushNamed(
            context,
            '/checkout?plan=$planId&period=${_isAnnual ? 'yearly' : 'monthly'}',
          );
          // Wait briefly, then reset loading state in case they navigate back
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) setState(() => _isPurchasing = false);
          });
        }
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        if (mounted) {
          final success = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AndroidCheckoutScreen(
                planId: planId,
                period: _isAnnual ? 'yearly' : 'monthly',
              ),
            ),
          );
          if (success == true) {
            _showSuccessAnimation();
          } else {
            setState(() => _isPurchasing = false);
          }
        }
      } else {
        // Find the matching RevenueCat package for iOS
        final package = _findPackage(planId, _isAnnual);
        if (package == null) {
          setState(() {
            _error = 'This plan is not available for purchase yet.';
            _isPurchasing = false;
          });
          return;
        }

        final success = await SubscriptionService.instance.purchasePackage(package);

        if (mounted) {
          if (success) {
            _showSuccessAnimation();
          } else {
            setState(() => _isPurchasing = false);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Purchase failed. Please try again.';
          _isPurchasing = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_isRestoring) return;
    setState(() {
      _isRestoring = true;
      _error = null;
    });

    final restored = await SubscriptionService.instance.restorePurchases();

    if (mounted) {
      if (restored) {
        _showSuccessAnimation();
      } else {
        setState(() {
          _isRestoring = false;
          _error = 'No previous purchases found.';
        });
      }
    }
  }

  /// Find the RevenueCat package matching a plan ID and billing period
  Package? _findPackage(String planId, bool isAnnual) {
    if (_packages.isEmpty) return null;

    final targetType = isAnnual ? PackageType.annual : PackageType.monthly;

    // Try to find an exact match by product ID containing the plan name
    for (final pkg in _packages) {
      final productId = pkg.storeProduct.identifier.toLowerCase();
      if (productId.contains(planId.replaceAll('_', '')) &&
          pkg.packageType == targetType) {
        return pkg;
      }
    }

    // Fallback: match by package type only
    for (final pkg in _packages) {
      if (pkg.packageType == targetType) {
        return pkg;
      }
    }

    return _packages.isNotEmpty ? _packages.first : null;
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PurchaseSuccessDialog(
        onDismiss: () {
          Navigator.pop(ctx);
          if (widget.isFromSignup) {
            Navigator.pushReplacementNamed(context, '/app');
          } else {
            Navigator.pop(context, true); // Return success to caller
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isDark),
            Expanded(
              child: _isLoading
                  ? _buildLoadingState(isDark)
                  : _buildContent(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────

  Widget _buildHeader(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            onPressed: () {
              if (widget.isFromSignup) {
                Navigator.pushReplacementNamed(context, '/app');
              } else {
                Navigator.pop(context);
              }
            },
            icon: Icon(
              widget.isFromSignup ? Icons.close_rounded : Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF1E88E5), Color(0xFF10D98C)],
            ).createShader(b),
            child: const Icon(Icons.sync_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 8),
          Text(
            'InkSync Pro',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          const SizedBox(width: 48), // Balance close button
        ],
      ),
    );
  }

  // ─── LOADING STATE ────────────────────────────────────────────────

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(
            valueColor: const AlwaysStoppedAnimation(AppTheme.primaryColor),
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading plans...',
            style: TextStyle(
              color: isDark ? Colors.white38 : AppTheme.textMuted,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ─── MAIN CONTENT ────────────────────────────────────────────────

  Widget _buildContent(bool isDark) {
    final premiumPlan = _plans['premium'];
    final proPlan = _plans['premium_pro'];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          const SizedBox(height: 28),

          // Context banner (if triggered from a specific feature)
          if (widget.featureContext != null) _buildContextBanner(isDark),

          // Hero
          _buildHero(isDark),
          const SizedBox(height: 28),

          // Monthly / Yearly toggle
          _buildToggle(isDark),
          const SizedBox(height: 24),

          // Plan cards
          if (premiumPlan != null)
            _buildPlanCard(
              isDark: isDark,
              planId: 'premium',
              title: 'Premium',
              subtitle: 'For power users',
              plan: premiumPlan,
              isHighlighted: true,
              badge: 'Most Popular',
              features: [
                '${premiumPlan.notesLimit} cross-platform notes',
                '${premiumPlan.aiCreditsLimit} AI writing credits / month',
                'Real-time collaboration',
                'Priority support',
              ],
            ),

          const SizedBox(height: 16),

          if (proPlan != null)
            _buildPlanCard(
              isDark: isDark,
              planId: 'premium_pro',
              title: 'Premium Pro',
              subtitle: 'For teams & pros',
              plan: proPlan,
              isHighlighted: false,
              features: [
                '${proPlan.notesLimit} cross-platform notes',
                '${proPlan.aiCreditsLimit} AI writing credits / month',
                'Advanced collaboration',
                'Priority support',
              ],
            ),

          const SizedBox(height: 24),

          // Error
          if (_error != null) _buildErrorBanner(isDark),

          // Restore purchases or Continue for Free
          if (!widget.isFromSignup) _buildRestoreButton(isDark),
          if (widget.isFromSignup) _buildContinueForFree(isDark),

          const SizedBox(height: 12),

          // Legal
          _buildLegalText(isDark),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ─── CONTEXT BANNER ──────────────────────────────────────────────

  Widget _buildContextBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.amber.withValues(alpha: 0.12)
            : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded,
              color: Colors.amber.shade700, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${widget.featureContext} requires a Premium subscription',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.amber.shade400 : Colors.amber.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── HERO ────────────────────────────────────────────────────────

  Widget _buildHero(bool isDark) {
    return Column(
      children: [
        // Animated gradient icon
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.primaryColor, Color(0xFF10D98C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(Icons.diamond_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(
          'Unlock your full potential',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : const Color(0xFF1E293B),
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'More notes. AI assist. Real-time collaboration.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            color: isDark ? Colors.white38 : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  // ─── TOGGLE ──────────────────────────────────────────────────────

  Widget _buildToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.04),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleTab('Monthly', !_isAnnual, isDark,
              () => setState(() => _isAnnual = false)),
          _toggleTab('Annually', _isAnnual, isDark,
              () => setState(() => _isAnnual = true)),
          if (_isAnnual)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: AppTheme.primaryColor.withValues(alpha: 0.15),
              ),
              child: const Text(
                'Save 20%',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toggleTab(
      String label, bool active, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active ? AppTheme.primaryColor : Colors.transparent,
          boxShadow: active
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active
                ? Colors.white
                : (isDark ? Colors.white54 : const Color(0xFF64748B)),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ─── PLAN CARD ───────────────────────────────────────────────────

  Widget _buildPlanCard({
    required bool isDark,
    required String planId,
    required String title,
    required String subtitle,
    required SubscriptionPlan plan,
    required bool isHighlighted,
    required List<String> features,
    String? badge,
  }) {
    final price = _isAnnual ? plan.priceYearly : plan.priceMonthly;
    final period = _isAnnual ? '/year' : '/month';
    final isCurrentPlan = SubscriptionService.instance.currentPlan == planId;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border.all(
          color: isHighlighted
              ? AppTheme.primaryColor.withValues(alpha: 0.4)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06)),
          width: isHighlighted ? 1.5 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          if (badge != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: const LinearGradient(
                  colors: [AppTheme.primaryColor, Color(0xFF10D98C)],
                ),
              ),
              child: Text(
                badge,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // Title & subtitle
          Text(
            title,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF1E293B),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: isDark ? Colors.white38 : const Color(0xFF64748B),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),

          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${price.toStringAsFixed(2)}',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Text(
                  period,
                  style: TextStyle(
                    color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Features
          ...features.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      color: AppTheme.primaryColor,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        f,
                        style: TextStyle(
                          color: isDark
                              ? Colors.white70
                              : const Color(0xFF475569),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 18),

          // CTA Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: isCurrentPlan || _isPurchasing
                  ? null
                  : () => _purchase(planId),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrentPlan
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                    : AppTheme.primaryColor,
                foregroundColor: isCurrentPlan
                    ? const Color(0xFF10B981)
                    : Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                disabledBackgroundColor: isCurrentPlan
                    ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                    : AppTheme.primaryColor.withValues(alpha: 0.6),
              ),
              child: _isPurchasing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isCurrentPlan) ...[
                          const Icon(Icons.check_circle_rounded,
                              size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 6),
                        ],
                        Text(
                          isCurrentPlan ? 'Current Plan' : 'Subscribe',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── ERROR BANNER ────────────────────────────────────────────────

  Widget _buildErrorBanner(bool isDark) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF7F1D1D).withValues(alpha: 0.3)
            : const Color(0xFFFEE2E2),
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
    );
  }

  // ─── RESTORE BUTTON ──────────────────────────────────────────────

  Widget _buildRestoreButton(bool isDark) {
    return TextButton(
      onPressed: _isRestoring ? null : _restore,
      child: _isRestoring
          ? SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white38 : AppTheme.textMuted,
              ),
            )
          : Text(
              'Restore Purchases',
              style: TextStyle(
                color: isDark ? Colors.white38 : const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  // ─── CONTINUE FOR FREE ───────────────────────────────────────────

  Widget _buildContinueForFree(bool isDark) {
    return TextButton(
      onPressed: () => Navigator.pushReplacementNamed(context, '/app'),
      child: Text(
        'Continue for Free',
        style: TextStyle(
          color: isDark ? Colors.white54 : const Color(0xFF64748B),
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // ─── LEGAL TEXT ──────────────────────────────────────────────────

  Widget _buildLegalText(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        'Payment will be charged to your ${defaultTargetPlatform == TargetPlatform.iOS ? 'Apple ID' : 'Google Play'} account. '
        'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. '
        'Manage subscriptions in your device settings.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white24 : Colors.grey.shade400,
          height: 1.5,
        ),
      ),
    );
  }
}

// ─── SUCCESS DIALOG ──────────────────────────────────────────────────

class _PurchaseSuccessDialog extends StatefulWidget {
  final VoidCallback onDismiss;
  const _PurchaseSuccessDialog({required this.onDismiss});

  @override
  State<_PurchaseSuccessDialog> createState() => _PurchaseSuccessDialogState();
}

class _PurchaseSuccessDialogState extends State<_PurchaseSuccessDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    // Auto-dismiss after 3 seconds
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
            // Animated checkmark
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
                      color:
                          const Color(0xFF10B981).withValues(alpha: 0.4),
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
