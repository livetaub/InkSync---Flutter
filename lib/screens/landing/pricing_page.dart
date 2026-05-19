import 'package:flutter/material.dart';
import '../../utils/platform_helper.dart' as platform;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

class PricingPage extends StatefulWidget {
  const PricingPage({super.key});
  @override
  State<PricingPage> createState() => _PricingPageState();
}

class _PricingPageState extends State<PricingPage> {
  bool _isAnnual = false;
  final _faqKey = GlobalKey();
  String _userAccountType = 'free';

  Map<String, Map<String, dynamic>> _pricingConfig = {
    'free': {'notes_limit': 75, 'ai_credits_limit': 0},
    'premium': {'price_monthly': 4.99, 'price_yearly': 49.99, 'notes_limit': 250, 'ai_credits_limit': 100},
    'premium_pro': {'price_monthly': 9.99, 'price_yearly': 99.99, 'notes_limit': 500, 'ai_credits_limit': 200},
  };

  @override
  void initState() {
    super.initState();
    _fetchPricing();
    _fetchUserAccountType();
  }

  Future<void> _fetchPricing() async {
    try {
      final response = await Supabase.instance.client.from('global_pricing').select();
      final newConfig = Map<String, Map<String, dynamic>>.from(_pricingConfig);
      for (final row in response) {
        newConfig[row['plan_id']] = row;
      }
      if (mounted) setState(() => _pricingConfig = newConfig);
    } catch (e) {
      debugPrint('Error fetching pricing: $e');
    }
  }

  Future<void> _fetchUserAccountType() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('account_type')
          .eq('id', userId)
          .single();
      if (mounted) {
        setState(() => _userAccountType = profile['account_type'] ?? 'free');
      }
    } catch (e) {
      debugPrint('Error fetching account type: $e');
    }
  }

  String _ctaLabel(String planId, bool isLoggedIn) {
    if (!isLoggedIn) return 'Create an account';
    if (planId == _userAccountType) return 'Current Plan';
    // Rank: free=0, premium=1, premium_pro=2
    const rank = {'free': 0, 'premium': 1, 'premium_pro': 2};
    final currentRank = rank[_userAccountType] ?? 0;
    final planRank = rank[planId] ?? 0;
    if (planRank > currentRank) return 'Upgrade';
    return 'Current Plan'; // don't show downgrade
  }

  void _nav(String path) {
    final origin = platform.getLocationOrigin();
    platform.setLocationHref('$origin/#$path');
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    final isMobile = w < 768;
    final isLoggedIn = Supabase.instance.client.auth.currentSession != null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SingleChildScrollView(
        child: Column(children: [
          _buildNav(isMobile, isLoggedIn),
          _buildHeader(isMobile),
          _buildToggle(),
          const SizedBox(height: 40),
          _buildCards(isMobile, isLoggedIn),
          const SizedBox(height: 64),
          _buildFaq(isMobile, key: _faqKey),
          _buildFooter(isMobile),
        ]),
      ),
    );
  }

  Widget _buildNav(bool isMobile, bool isLoggedIn) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 48, vertical: 16),
      child: Row(children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => _nav('/'),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              ShaderMask(
                shaderCallback: (b) => const LinearGradient(colors: [Color(0xFF1E88E5), Color(0xFF10D98C)]).createShader(b),
                child: const Icon(Icons.sync_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 8),
              const Text('InkSync', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
            ]),
          ),
        ),
        const Spacer(),
        if (!isMobile) ...[
          _navLink('Home', () => _nav('/')),
          const SizedBox(width: 28),
          _navLink('Features', () => _nav('/')),
          const SizedBox(width: 28),
          _navLink('FAQ', () {
            Scrollable.ensureVisible(
              _faqKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }),
          const SizedBox(width: 28),
          if (!isLoggedIn) _navLink('Sign In', () => _nav('/login')),
          if (!isLoggedIn) const SizedBox(width: 20),
        ],
        const SizedBox(width: 20),
        if (isLoggedIn)
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => _nav('/app'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF10D98C)])),
                child: const Text('Go to App', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        if (isMobile) ...[
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.white70),
            onPressed: () => _showMobileMenu(isLoggedIn),
          ),
        ],
      ]),
    );
  }

  void _showMobileMenu(bool isLoggedIn) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          _menuItem('Home', Icons.home_rounded, () { Navigator.pop(ctx); _nav('/'); }),
          _menuItem('Features', Icons.auto_awesome_rounded, () { Navigator.pop(ctx); _nav('/'); }),
          _menuItem('Pricing', Icons.diamond_outlined, () { Navigator.pop(ctx); }),
          _menuItem('FAQ', Icons.help_outline_rounded, () {
            Navigator.pop(ctx);
            Scrollable.ensureVisible(
              _faqKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            );
          }),
          if (!isLoggedIn) _menuItem('Sign In', Icons.login_rounded, () { Navigator.pop(ctx); _nav('/login'); }),
          if (isLoggedIn) _menuItem('Go to App', Icons.dashboard_rounded, () { Navigator.pop(ctx); _nav('/app'); }),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  Widget _menuItem(String label, IconData icon, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.primaryColor, size: 22),
      title: Text(label, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: onTap,
    );
  }

  Widget _navLink(String label, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, isMobile ? 40 : 64, 24, 32),
      child: Column(children: [
        Text('Simple, transparent pricing', textAlign: TextAlign.center, style: TextStyle(fontSize: isMobile ? 32 : 48, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B), letterSpacing: -1, height: 1.1)),
        const SizedBox(height: 16),
        Text('Start free. Upgrade when you need more.', style: const TextStyle(color: Color(0xFF64748B), fontSize: 16)),
      ]),
    );
  }

  Widget _buildToggle() {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), color: Colors.black.withValues(alpha: 0.04), border: Border.all(color: Colors.black.withValues(alpha: 0.05))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _toggleTab('Monthly', !_isAnnual, () => setState(() => _isAnnual = false)),
          _toggleTab('Annually', _isAnnual, () => setState(() => _isAnnual = true)),
          if (_isAnnual)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), color: AppTheme.primaryColor.withValues(alpha: 0.15)),
              child: const Text('Save 20%', style: TextStyle(color: AppTheme.primaryColor, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),
    );
  }

  Widget _toggleTab(String label, bool active, VoidCallback onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: active ? AppTheme.primaryColor : Colors.transparent, boxShadow: active ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))] : null),
          child: Text(label, style: TextStyle(color: active ? Colors.white : const Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildCards(bool isMobile, bool isLoggedIn) {
    final freeConfig = _pricingConfig['free']!;
    final premiumConfig = _pricingConfig['premium']!;
    final proConfig = _pricingConfig['premium_pro']!;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 16 : 48),
      child: Wrap(
        spacing: 16, runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          _tierCard(
            isMobile: isMobile,
            isLoggedIn: isLoggedIn,
            planId: 'free',
            title: 'Free',
            subtitle: 'For personal use',
            price: '\$0',
            period: 'forever',
            features: [
              '${freeConfig['notes_limit']} cross-platform notes',
              'Notes & checklists',
              'Link notes to calendar',
              'Filter by tags & colors',
              'Lock notes for privacy',
              'Web, iOS & Android',
            ],
            cta: _ctaLabel('free', isLoggedIn),
            highlighted: false,
          ),
          _tierCard(
            isMobile: isMobile,
            isLoggedIn: isLoggedIn,
            planId: 'premium',
            title: 'Premium',
            subtitle: 'For power users',
            price: _isAnnual ? '\$${premiumConfig['price_yearly']}' : '\$${premiumConfig['price_monthly']}',
            period: _isAnnual ? '/year' : '/month',
            features: [
              'Everything in Free, plus:',
              '${premiumConfig['notes_limit']} cross-platform notes',
              '${premiumConfig['ai_credits_limit']} AI writing assist credits',
              'Real-time collaboration',
              'Priority support',
            ],
            cta: _ctaLabel('premium', isLoggedIn),
            highlighted: true,
            badge: 'Most Popular',
          ),
          _tierCard(
            isMobile: isMobile,
            isLoggedIn: isLoggedIn,
            planId: 'premium_pro',
            title: 'Premium Pro',
            subtitle: 'For teams & pros',
            price: _isAnnual ? '\$${proConfig['price_yearly']}' : '\$${proConfig['price_monthly']}',
            period: _isAnnual ? '/year' : '/month',
            features: [
              'Everything in Premium, plus:',
              '${proConfig['notes_limit']} cross-platform notes',
              '${proConfig['ai_credits_limit']} AI writing assist credits',
              'Advanced collaboration',
              'Priority support',
            ],
            cta: _ctaLabel('premium_pro', isLoggedIn),
            highlighted: false,
          ),
        ],
      ),
    );
  }

  Widget _tierCard({
    required bool isMobile,
    required bool isLoggedIn,
    required String planId,
    required String title,
    required String subtitle,
    required String price,
    required String period,
    required List<String> features,
    required String cta,
    required bool highlighted,
    String? badge,
  }) {
    return Container(
      width: isMobile ? double.infinity : 320,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: highlighted ? Colors.white : Colors.white,
        border: Border.all(
          color: highlighted ? AppTheme.primaryColor.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.05),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted 
            ? [BoxShadow(color: AppTheme.primaryColor.withValues(alpha: 0.1), blurRadius: 40, offset: const Offset(0, 16))] 
            : [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (badge != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(6), gradient: const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF10D98C)])),
            child: Text(badge, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 16),
        ],
        Text(title, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
        const SizedBox(height: 20),
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(price, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 40, fontWeight: FontWeight.w800, height: 1)),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(period, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14)),
          ),
        ]),
        const SizedBox(height: 24),
        ...features.map((f) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(children: [
            Icon(
              f.startsWith('Everything') ? Icons.arrow_upward_rounded : Icons.check_circle_rounded,
              color: f.startsWith('Everything') ? const Color(0xFF6366F1) : AppTheme.primaryColor,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(f, style: TextStyle(color: f.startsWith('Everything') ? const Color(0xFF1E293B) : const Color(0xFF475569), fontSize: 14, fontWeight: f.startsWith('Everything') ? FontWeight.w600 : FontWeight.w400))),
          ]),
        )),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: MouseRegion(
            cursor: cta == 'Current Plan' ? SystemMouseCursors.basic : SystemMouseCursors.click,
            child: GestureDetector(
              onTap: cta == 'Current Plan' ? null : () {
                if (isLoggedIn) {
                  if (planId == 'free') {
                    _nav('/app');
                  } else {
                    final billingPeriod = _isAnnual ? 'yearly' : 'monthly';
                    _nav('/checkout?plan=$planId&period=$billingPeriod');
                  }
                } else {
                  _showPlanSignupDialog(planId, title);
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: cta == 'Current Plan'
                      ? null
                      : highlighted ? const LinearGradient(colors: [AppTheme.primaryColor, Color(0xFF10D98C)]) : null,
                  color: cta == 'Current Plan' ? const Color(0xFFF1F5F9) : null,
                  border: (highlighted && cta != 'Current Plan') ? null : Border.all(color: Colors.black.withValues(alpha: 0.08)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (cta == 'Current Plan') ...[
                      const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF10B981)),
                      const SizedBox(width: 6),
                    ],
                    Text(cta, textAlign: TextAlign.center, style: TextStyle(
                      color: cta == 'Current Plan' ? const Color(0xFF10B981) : highlighted ? Colors.white : const Color(0xFF475569),
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  // ─── SIGNUP DIALOG ──────────────────────────────────────────
  void _showPlanSignupDialog(String planId, String planTitle) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool obscurePassword = true;
    bool obscureConfirm = true;
    bool isLoading = false;
    String? errorMessage;
    final isPaid = planId != 'free';

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 420),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 40, offset: const Offset(0, 20))],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ── Logo ──
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                          ),
                          child: Icon(isPaid ? Icons.diamond_rounded : Icons.person_add_rounded, size: 28, color: Colors.white),
                        ),
                        const SizedBox(height: 20),
                        Text('Create your $planTitle account', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF1E293B), letterSpacing: -0.5)),
                        const SizedBox(height: 6),
                        Text(
                          isPaid ? 'Set up your account and payment' : 'Get started for free — no credit card required',
                          style: const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                        ),
                        const SizedBox(height: 24),

                        // ── Google Sign-In ──
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: OutlinedButton(
                            onPressed: isLoading ? null : () async {
                              setDialogState(() { isLoading = true; errorMessage = null; });
                              try {
                                // Save pending plan so we can resume checkout after OAuth redirect
                                if (isPaid) {
                                  final billingPeriod = _isAnnual ? 'yearly' : 'monthly';
                                  platform.setLocalStorageValue('pending_plan', planId);
                                  platform.setLocalStorageValue('pending_period', billingPeriod);
                                }
                                final authService = Provider.of<AuthService>(ctx, listen: false);
                                await authService.signInWithGoogle();
                              } catch (e) {
                                setDialogState(() { isLoading = false; errorMessage = e.toString().replaceAll('Exception: ', ''); });
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFFE2E8F0)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.white,
                            ),
                            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg', width: 20, height: 20, errorBuilder: (_, __, ___) => const Icon(Icons.g_mobiledata, size: 20)),
                              const SizedBox(width: 10),
                              const Text('Continue with Google', style: TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w600)),
                            ]),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Divider ──
                        Row(children: [
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('or', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                          Expanded(child: Divider(color: Colors.grey.shade200)),
                        ]),
                        const SizedBox(height: 20),

                        // ── Form ──
                        Form(
                          key: formKey,
                          child: Column(children: [
                            _dialogField(emailController, 'Email address', Icons.email_outlined, false),
                            const SizedBox(height: 14),
                            _dialogPasswordField(passwordController, 'Password', obscurePassword, () => setDialogState(() => obscurePassword = !obscurePassword)),
                            const SizedBox(height: 14),
                            _dialogPasswordField(confirmPasswordController, 'Confirm password', obscureConfirm, () => setDialogState(() => obscureConfirm = !obscureConfirm), matchController: passwordController),
                          ]),
                        ),
                        const SizedBox(height: 20),

                        // ── Error ──
                        if (errorMessage != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFECACA))),
                            child: Row(children: [
                              const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 18),
                              const SizedBox(width: 8),
                              Expanded(child: Text(errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontSize: 13))),
                            ]),
                          ),

                        // ── Submit ──
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: isLoading ? null : () async {
                              if (!formKey.currentState!.validate()) return;
                              setDialogState(() { isLoading = true; errorMessage = null; });
                              try {
                                final authService = Provider.of<AuthService>(ctx, listen: false);
                                await authService.signUp(emailController.text.trim(), passwordController.text);
                                if (ctx.mounted) Navigator.pop(ctx);
                                if (isPaid) {
                                  final billingPeriod = _isAnnual ? 'yearly' : 'monthly';
                                  _nav('/checkout?plan=$planId&period=$billingPeriod');
                                } else {
                                  _nav('/app');
                                }
                              } catch (e) {
                                setDialogState(() { isLoading = false; errorMessage = e.toString().replaceAll('Exception: ', ''); });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: isLoading
                                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                                : Text(isPaid ? 'Create Account & Continue to Payment' : 'Create Free Account', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // ── Back to sign in ──
                        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Text('Already have an account? ', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                          GestureDetector(
                            onTap: () { Navigator.pop(ctx); _nav('/login'); },
                            child: const Text('Sign in', style: TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.w600, fontSize: 13)),
                          ),
                        ]),
                        if (isPaid) ...[
                          const SizedBox(height: 14),
                          Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.lock_rounded, size: 13, color: Colors.grey.shade400),
                            const SizedBox(width: 4),
                            Text('Payment details on next step • Secured by Stripe', style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
                          ]),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _dialogField(TextEditingController controller, String hint, IconData icon, bool obscure) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: hint.contains('Email') ? TextInputType.emailAddress : null,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: Icon(icon, color: const Color(0xFF94A3B8), size: 20),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (hint.contains('Email') && !v.contains('@')) return 'Enter a valid email';
        return null;
      },
    );
  }

  Widget _dialogPasswordField(TextEditingController controller, String hint, bool obscure, VoidCallback toggle, {TextEditingController? matchController}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Color(0xFF1E293B)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF94A3B8), size: 20),
        suffixIcon: IconButton(icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFF94A3B8), size: 20), onPressed: toggle),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF10B981), width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      validator: (v) {
        if (v == null || v.isEmpty) return 'Required';
        if (v.length < 6) return 'Min 6 characters';
        if (matchController != null && v != matchController.text) return 'Passwords don\'t match';
        return null;
      },
    );
  }

  Widget _buildFaq(bool isMobile, {Key? key}) {
    return Container(
      key: key,
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: 48),
      child: Column(children: [
        const Text('Frequently asked questions', style: TextStyle(color: Color(0xFF1E293B), fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(height: 32),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(children: [
            _faqItem('Can I use InkSync for free?', 'Absolutely! The free tier includes 75 notes with full cross-platform sync, tags, colors, calendar linking, and note locking. No credit card required.'),
            _faqItem('What happens when I reach my note limit?', 'You\'ll be prompted to upgrade or delete existing notes. Your existing notes are never deleted automatically.'),
            _faqItem('Can I switch plans anytime?', 'Yes — upgrade, downgrade, or cancel at any time. Changes take effect at the end of your current billing cycle.'),
            _faqItem('What are AI writing assist credits?', 'Each credit lets you use the AI assistant once to help draft, rewrite, or expand text in your notes. Credits refresh monthly.'),
            _faqItem('Is my data secure?', 'Yes. All data is encrypted in transit and at rest. Note locking adds an extra layer of privacy for sensitive content.'),
          ]),
        ),
      ]),
    );
  }

  Widget _faqItem(String q, String a) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: Colors.white, border: Border.all(color: Colors.black.withValues(alpha: 0.05)), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          title: Text(q, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 15, fontWeight: FontWeight.w600)),
          iconColor: const Color(0xFF94A3B8),
          collapsedIconColor: const Color(0xFF94A3B8),
          children: [Text(a, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, height: 1.6))],
        ),
      ),
    );
  }

  Widget _buildFooter(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 64, vertical: 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.black.withValues(alpha: 0.05)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text('© 2026 InkSync', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
        const Spacer(),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(onTap: () => _nav('/'), child: const Text('Home', style: TextStyle(color: Color(0xFF64748B), fontSize: 13))),
        ),
      ]),
    );
  }
}
