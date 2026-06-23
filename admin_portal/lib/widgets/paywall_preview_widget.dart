import 'package:flutter/material.dart';
import '../theme.dart';

class PaywallPreviewWidget extends StatefulWidget {
  final Map<String, dynamic> variantData;
  final bool isMobileView;

  const PaywallPreviewWidget({
    super.key,
    required this.variantData,
    required this.isMobileView,
  });

  @override
  State<PaywallPreviewWidget> createState() => _PaywallPreviewWidgetState();
}

class _PaywallPreviewWidgetState extends State<PaywallPreviewWidget> {
  bool _isAnnual = true;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> get _data => widget.variantData;

  List<String> _parseFeatures(dynamic f) {
    if (f is List) {
      return f.map((e) => e.toString()).where((s) => s.isNotEmpty).toList();
    }
    if (f is String) {
      return f.split('\n').where((s) => s.trim().isNotEmpty).toList();
    }
    return [];
  }

  double _parsePrice(dynamic v) =>
      double.tryParse(v?.toString() ?? '') ?? 0.0;

  String _fmt(double price) => price.toStringAsFixed(2);

  // ---------------------------------------------------------------------------
  // Shared constants
  // ---------------------------------------------------------------------------

  static const _primaryColor = AppTheme.primaryColor; // 0xFF10B981
  static const _accentGradient = [Color(0xFF1E88E5), Color(0xFF10D98C)];
  static const _badgeGradient = [Color(0xFF10B981), Color(0xFF10D98C)];
  static const _textDark = Color(0xFF1E293B);
  static const _textMuted = Color(0xFF64748B);
  static const _textLight = Color(0xFF94A3B8);
  static const _cardBg = Colors.white;
  static const _previewBg = Color(0xFFF8FAFC);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _previewBg,
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.isMobileView ? _buildMobilePreview() : _buildWebPreview(),
    );
  }

  // ===========================================================================
  // MOBILE PREVIEW
  // ===========================================================================

  Widget _buildMobilePreview() {
    final headline = _data['page_headline']?.toString() ?? '';
    final subheadline = _data['page_subheadline']?.toString() ?? '';
    final trialText = _data['trial_text']?.toString() ?? '';
    final moneyBackText = _data['money_back_text']?.toString() ?? '';

    return Center(
      child: Container(
        width: 375,
        color: _previewBg,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              // Header
              _mobileHeader(),
              // Hero
              _mobileHero(headline, subheadline),
              const SizedBox(height: 20),
              // Toggle
              _billingToggle(),
              const SizedBox(height: 20),
              // Premium card
              _mobilePlanCard(
                badgeText:
                    _data['premium_badge_text']?.toString() ?? 'Most Popular',
                title: _data['premium_title']?.toString() ?? 'Premium',
                subtitle: _data['premium_subtitle']?.toString() ?? '',
                price: _isAnnual
                    ? _parsePrice(_data['premium_price_yearly'])
                    : _parsePrice(_data['premium_price_monthly']),
                period: _isAnnual ? '/year' : '/month',
                features: _parseFeatures(_data['premium_features']),
                ctaText: _isAnnual
                    ? (_data['premium_cta_yearly']?.toString() ??
                        'Start Free Trial')
                    : (_data['premium_cta_monthly']?.toString() ??
                        'Start Free Trial'),
                highlighted: true,
              ),

              const SizedBox(height: 20),
              // Continue for free
              Text(
                'Continue for Free',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              // Legal
              if (trialText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    trialText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: _textLight),
                  ),
                ),
              if (moneyBackText.isNotEmpty) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    moneyBackText,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: _textLight),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: _accentGradient,
            ).createShader(bounds),
            child: const Icon(Icons.diamond, size: 24, color: Colors.white),
          ),
          const SizedBox(width: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: _accentGradient,
            ).createShader(bounds),
            child: const Text(
              'InkSync Premium',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mobileHero(String headline, String subheadline) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: _accentGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      height: 72,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (headline.isNotEmpty)
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          if (subheadline.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subheadline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.9),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _mobilePlanCard({
    required String badgeText,
    required String title,
    required String subtitle,
    required double price,
    required String period,
    required List<String> features,
    required String ctaText,
    required bool highlighted,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: highlighted
              ? _primaryColor.withValues(alpha: 0.4)
              : Colors.black.withValues(alpha: 0.05),
          width: highlighted ? 1.5 : 1,
        ),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: _primaryColor.withValues(alpha: 0.10),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Badge
          if (badgeText.isNotEmpty) _gradientBadge(badgeText),
          if (badgeText.isNotEmpty) const SizedBox(height: 12),
          // Title & subtitle
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _textDark,
            ),
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 13, color: _textMuted),
            ),
          ],
          const SizedBox(height: 12),
          // Price
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${_fmt(price)}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: _textDark,
                  height: 1,
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  period,
                  style: const TextStyle(fontSize: 14, color: _textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Features
          ...features.map((f) => _featureRow(f)),
          const SizedBox(height: 16),
          // CTA
          _ctaButton(ctaText, gradient: highlighted, borderRadius: 14),
        ],
      ),
    );
  }

  // ===========================================================================
  // WEB PREVIEW
  // ===========================================================================

  Widget _buildWebPreview() {
    final headline = _data['page_headline']?.toString() ?? 'Unlock your full potential';
    final subheadline = _data['page_subheadline']?.toString() ?? 'More notes. AI assist. Real-time collaboration.';
    final trialText = _data['trial_text']?.toString() ?? '';
    final moneyBackText = _data['money_back_text']?.toString() ?? '';

    return Container(
      color: _previewBg,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        child: Column(
          children: [
            // Header
            _webHeader(),
            const SizedBox(height: 12),
            // Hero
            _webHero(headline, subheadline),
            const SizedBox(height: 28),
            // Toggle
            _billingToggle(),
            const SizedBox(height: 32),
            // Cards
            Wrap(
              spacing: 20,
              runSpacing: 20,
              alignment: WrapAlignment.center,
              children: [
                _webTierCard(
                  title: _data['premium_title']?.toString() ?? 'Premium',
                  subtitle: _data['premium_subtitle']?.toString() ?? '',
                  priceLabel: _isAnnual
                      ? '\$${_fmt(_parsePrice(_data['premium_price_yearly']))}'
                      : '\$${_fmt(_parsePrice(_data['premium_price_monthly']))}',
                  priceSuffix: _isAnnual ? '/year' : '/month',
                  features: _parseFeatures(_data['premium_features']),
                  ctaText: _isAnnual
                      ? (_data['premium_cta_yearly']?.toString() ??
                          'Start Free Trial')
                      : (_data['premium_cta_monthly']?.toString() ??
                          'Start Free Trial'),
                  highlighted: true,
                  badgeText: _data['premium_badge_text']?.toString(),

                ),

              ],
            ),
            const SizedBox(height: 28),
            // Legal
            if (trialText.isNotEmpty)
              Text(
                trialText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _textLight),
              ),
            if (moneyBackText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                moneyBackText,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _textLight),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _webHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: _accentGradient,
          ).createShader(bounds),
          child: const Icon(Icons.diamond, size: 28, color: Colors.white),
        ),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: _accentGradient,
          ).createShader(bounds),
          child: const Text(
            'InkSync Premium',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  Widget _webHero(String headline, String subheadline) {
    return Container(
      width: 580,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: _accentGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10D98C).withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (headline.isNotEmpty)
            Text(
              headline,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          if (subheadline.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              subheadline,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _webTierCard({
    required String title,
    required String subtitle,
    required String priceLabel,
    required String priceSuffix,
    required List<String> features,
    required String ctaText,
    required bool highlighted,
    required String? badgeText,

  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(24),
        border: highlighted
            ? null
            : Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      foregroundDecoration: highlighted
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                width: 2,
                color: Colors.transparent,
              ),
            )
          : null,
      child: Container(
        decoration: highlighted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(24),
              )
            : null,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge
                if (badgeText != null && badgeText.isNotEmpty) ...[
                  _gradientBadge(badgeText),
                  const SizedBox(height: 12),
                ],
                // Title
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textDark,
                  ),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 13, color: _textMuted),
                  ),
                ],
                const SizedBox(height: 16),
                // Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      priceLabel,
                      style: const TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: _textDark,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(
                        priceSuffix,
                        style:
                            const TextStyle(fontSize: 14, color: _textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                // Features
                ...features.map((f) => _featureRow(f)),
                const SizedBox(height: 20),
                // CTA
                _ctaButton(ctaText, gradient: highlighted, borderRadius: 12),
              ],
            ),
            // Gradient border overlay for highlighted card
            if (highlighted)
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _primaryColor.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SHARED COMPONENTS
  // ===========================================================================

  Widget _billingToggle() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _toggleOption('Monthly', !_isAnnual),
        const SizedBox(width: 4),
        _toggleOption('Annually', _isAnnual, showBadge: true),
      ],
    );
  }

  Widget _toggleOption(String label, bool selected, {bool showBadge = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isAnnual = label == 'Annually';
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? null
              : Border.all(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : _textMuted,
              ),
            ),
            if (showBadge) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.25)
                      : _primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Save ${(_data['premium_discount_pct'] as num? ?? 20).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : _primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _gradientBadge(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: _badgeGradient),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _featureRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle, size: 18, color: _primaryColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: _textDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ctaButton(String text,
      {bool gradient = false, double borderRadius = 14}) {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        gradient: gradient
            ? const LinearGradient(colors: _accentGradient)
            : null,
        color: gradient ? null : _primaryColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      alignment: Alignment.center,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }


}
