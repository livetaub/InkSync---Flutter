import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/admin_scaffold.dart';
import '../widgets/paywall_preview_widget.dart';

/// Paywall Variant Editor — Split-pane layout
///
/// Left panel: form fields organized in collapsible sections
/// Right panel: live preview with Mobile / Web toggle
class PaywallEditorScreen extends StatefulWidget {
  final String? variantId; // null = create new

  const PaywallEditorScreen({super.key, this.variantId});

  @override
  State<PaywallEditorScreen> createState() => _PaywallEditorScreenState();
}

class _PaywallEditorScreenState extends State<PaywallEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isMobilePreview = true;
  bool get _isNew => widget.variantId == null;

  // Controllers
  late final _EditorControllers _c;

  @override
  void initState() {
    super.initState();
    _c = _EditorControllers();
    _loadVariant();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _loadVariant() async {
    if (_isNew) {
      _c.setDefaults();
      setState(() => _isLoading = false);
      return;
    }

    try {
      final data = await Supabase.instance.client
          .from('paywall_variants')
          .select()
          .eq('id', widget.variantId!)
          .single();
      _c.populateFrom(data);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading variant: $e'), backgroundColor: Colors.red),
        );
        context.go('/paywall');
      }
    }
  }

  Future<void> _save() async {
    if (_c.variantName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Variant name is required.'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final data = _c.toMap();
      if (_isNew) {
        data['is_active'] = false;
        await Supabase.instance.client.from('paywall_variants').insert(data);
      } else {
        await Supabase.instance.client
            .from('paywall_variants')
            .update(data)
            .eq('id', widget.variantId!);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isNew ? 'Variant created.' : 'Variant saved.'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        context.go('/paywall');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Calculate yearly price: monthly * 12 * (1 - discount/100), rounded to .99
  static double _calcYearly(double monthly, double discountPct) {
    final raw = monthly * 12 * (1 - discountPct / 100);
    return raw.floorToDouble() + 0.99;
  }

  Map<String, dynamic> _buildPreviewData() {
    final premiumMonthly = double.tryParse(_c.premiumPriceMonthly.text) ?? 0;
    final premiumDiscount = double.tryParse(_c.premiumDiscountPct.text) ?? 0;

    return {
      'page_headline': _c.pageHeadline.text,
      'page_subheadline': _c.pageSubheadline.text,
      'trial_text': _c.trialText.text,
      'money_back_text': _c.moneyBackText.text,
      // Premium
      'premium_title': _c.premiumTitle.text,
      'premium_subtitle': _c.premiumSubtitle.text,
      'premium_badge_text': _c.premiumBadge.text,
      'premium_price_monthly': premiumMonthly,
      'premium_price_yearly': _calcYearly(premiumMonthly, premiumDiscount),
      'premium_cta_monthly': _c.premiumCtaMonthly.text,
      'premium_cta_yearly': _c.premiumCtaYearly.text,
      'premium_features': _c.premiumFeatures.text.split('\n').where((s) => s.trim().isNotEmpty).toList(),
      'premium_discount_pct': premiumDiscount,
    };
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: _isNew ? 'Create Variant' : 'Edit Variant',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Top bar with actions
                _buildTopBar(),
                // Split pane
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left: Form
                      Expanded(
                        flex: 45,
                        child: _buildForm(),
                      ),
                      // Divider
                      Container(width: 1, color: Colors.black.withValues(alpha: 0.06)),
                      // Right: Preview
                      Expanded(
                        flex: 55,
                        child: _buildPreviewPanel(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // ─── Top Bar ────────────────────────────────────────────────────

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.go('/paywall'),
            borderRadius: BorderRadius.circular(8),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.arrow_back_rounded, size: 18, color: Color(0xFF64748B)),
                  SizedBox(width: 6),
                  Text('Back to Variants', style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => context.go('/paywall'),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isNew ? 'Create Variant' : 'Save Changes'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Form Panel ─────────────────────────────────────────────────

  Widget _buildForm() {
    return Container(
      color: const Color(0xFFFAFAFA),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Headline & Subheadline
              Row(children: [
                Expanded(child: _field('Page Headline', _c.pageHeadline)),
                const SizedBox(width: 12),
                Expanded(child: _field('Page Subheadline', _c.pageSubheadline)),
              ]),
              const SizedBox(height: 12),

              // Pricing
              Row(children: [
                Expanded(child: _field('Monthly Price (\$)', _c.premiumPriceMonthly, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _field('Annual Discount %', _c.premiumDiscountPct, isNumber: true)),
                const SizedBox(width: 12),
                Expanded(child: _readonlyPrice('Computed Yearly Price', _c.premiumPriceMonthly, _c.premiumDiscountPct)),
              ]),
              const SizedBox(height: 12),

              // CTAs
              Row(children: [
                Expanded(child: _field('CTA Button Monthly', _c.premiumCtaMonthly)),
                const SizedBox(width: 12),
                Expanded(child: _field('CTA Button Yearly', _c.premiumCtaYearly)),
              ]),
              const SizedBox(height: 12),

              // Guarantees / Footer Copy
              Row(children: [
                Expanded(child: _field('Trial Text (e.g. 3-day free trial)', _c.trialText)),
                const SizedBox(width: 12),
                Expanded(child: _field('Money-back Guarantee Text', _c.moneyBackText)),
              ]),
              const SizedBox(height: 12),

              // Features List
              _field('Premium Features (one per line)', _c.premiumFeatures, minLines: 2),
              const SizedBox(height: 16),

              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 12),

              // Variant Identity (Admin config)
              Row(children: [
                Expanded(child: _field('Variant Name *', _c.variantName)),
                const SizedBox(width: 12),
                SizedBox(width: 120, child: _field('Traffic Weight %', _c.trafficWeight, isNumber: true)),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController controller, {bool isNumber = false, int maxLines = 1, int? minLines}) {
    return TextField(
      controller: controller,
      maxLines: minLines != null ? null : maxLines,
      minLines: minLines,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : null,
      style: const TextStyle(fontSize: 13),
      onChanged: (_) => setState(() {}), // trigger preview rebuild
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
        ),
        filled: true,
        fillColor: const Color(0xFFFCFCFC),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  /// Read-only computed yearly price display
  Widget _readonlyPrice(String label, TextEditingController monthlyCtrl, TextEditingController discountCtrl) {
    final monthly = double.tryParse(monthlyCtrl.text) ?? 0;
    final discount = double.tryParse(discountCtrl.text) ?? 0;
    final yearly = _calcYearly(monthly, discount);
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
        ),
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      child: Text(
        '\$${yearly.toStringAsFixed(2)}',
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF10B981)),
      ),
    );
  }

  // ─── Preview Panel ──────────────────────────────────────────────

  Widget _buildPreviewPanel() {
    return Container(
      color: const Color(0xFFF1F5F9),
      child: Column(
        children: [
          // Preview toggle bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(bottom: BorderSide(color: Colors.black.withValues(alpha: 0.06))),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, size: 16, color: Color(0xFF64748B)),
                const SizedBox(width: 8),
                const Text('Live Preview', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                const Spacer(),
                // Mobile / Web toggle
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF1F5F9),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _previewToggle('Mobile', Icons.phone_iphone_rounded, _isMobilePreview, () => setState(() => _isMobilePreview = true)),
                      const SizedBox(width: 2),
                      _previewToggle('Web', Icons.computer_rounded, !_isMobilePreview, () => setState(() => _isMobilePreview = false)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Preview content
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _isMobilePreview ? _buildMobileFrame() : _buildWebFrame(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _previewToggle(String label, IconData icon, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: active ? Colors.white : Colors.transparent,
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: active ? const Color(0xFF1E293B) : const Color(0xFF94A3B8)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: active ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFrame() {
    return Container(
      width: 375,
      constraints: const BoxConstraints(maxHeight: 780),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(40),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 40, offset: const Offset(0, 16)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(38),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(36),
            child: PaywallPreviewWidget(
              variantData: _buildPreviewData(),
              isMobileView: true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWebFrame() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 900),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        children: [
          // Fake browser bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF334155),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Row(
                  children: [
                    Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFEF4444))),
                    const SizedBox(width: 6),
                    Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFBBF24))),
                    const SizedBox(width: 6),
                    Container(width: 12, height: 12, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF22C55E))),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'app.inksyncnote.com/pricing',
                      style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Web preview content
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            child: PaywallPreviewWidget(
              variantData: _buildPreviewData(),
              isMobileView: false,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// Editor Controllers
// ═══════════════════════════════════════════════════════════════

class _EditorControllers {
  final variantName = TextEditingController();
  final trafficWeight = TextEditingController();
  final pageHeadline = TextEditingController();
  final pageSubheadline = TextEditingController();
  final trialText = TextEditingController();
  final moneyBackText = TextEditingController();

  // Premium
  final premiumTitle = TextEditingController();
  final premiumSubtitle = TextEditingController();
  final premiumBadge = TextEditingController();
  final premiumPriceMonthly = TextEditingController();
  final premiumDiscountPct = TextEditingController();
  final premiumCtaMonthly = TextEditingController();
  final premiumCtaYearly = TextEditingController();
  final premiumFeatures = TextEditingController();

  // Pro controllers removed — only Premium tier remains

  List<TextEditingController> get _all => [
    variantName, trafficWeight, pageHeadline, pageSubheadline, trialText, moneyBackText,
    premiumTitle, premiumSubtitle, premiumBadge, premiumPriceMonthly, premiumDiscountPct, premiumCtaMonthly, premiumCtaYearly, premiumFeatures,
  ];

  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
  }

  /// Calculate yearly price: monthly * 12 * (1 - discount/100), rounded to .99
  static double _calcYearly(double monthly, double discountPct) {
    final raw = monthly * 12 * (1 - discountPct / 100);
    return raw.floorToDouble() + 0.99;
  }

  /// Reverse-calculate discount % from stored monthly + yearly prices
  static double _reverseDiscount(double monthly, double yearly) {
    if (monthly <= 0) return 0;
    final fullYearly = monthly * 12;
    if (fullYearly <= 0) return 0;
    return ((1 - yearly / fullYearly) * 100).roundToDouble();
  }

  void setDefaults() {
    variantName.text = '';
    trafficWeight.text = '50';
    pageHeadline.text = 'Unlock your full potential';
    pageSubheadline.text = 'More notes. AI assist. Real-time collaboration.';
    premiumTitle.text = 'Premium';
    premiumSubtitle.text = 'For power users';
    premiumBadge.text = 'Most Popular';
    premiumPriceMonthly.text = '4.99';
    premiumDiscountPct.text = '20';
    premiumCtaMonthly.text = 'Subscribe';
    premiumCtaYearly.text = 'Subscribe';
    premiumFeatures.text = '250 cross-platform notes\n100 AI writing credits / month\nReal-time collaboration\nPriority support';
  }

  void populateFrom(Map<String, dynamic> data) {
    variantName.text = data['variant_name']?.toString() ?? '';
    trafficWeight.text = (data['traffic_weight'] ?? 50).toString();
    pageHeadline.text = data['page_headline']?.toString() ?? '';
    pageSubheadline.text = data['page_subheadline']?.toString() ?? '';
    trialText.text = data['trial_text']?.toString() ?? '';
    moneyBackText.text = data['money_back_text']?.toString() ?? '';

    premiumTitle.text = data['premium_title']?.toString() ?? 'Premium';
    premiumSubtitle.text = data['premium_subtitle']?.toString() ?? '';
    premiumBadge.text = data['premium_badge_text']?.toString() ?? '';
    final premMonthly = (data['premium_price_monthly'] ?? 4.99) as num;
    final premYearly = (data['premium_price_yearly'] ?? 49.99) as num;
    premiumPriceMonthly.text = premMonthly.toString();
    premiumDiscountPct.text = _reverseDiscount(premMonthly.toDouble(), premYearly.toDouble()).toStringAsFixed(0);
    premiumCtaMonthly.text = data['premium_cta_monthly']?.toString() ?? 'Subscribe';
    premiumCtaYearly.text = data['premium_cta_yearly']?.toString() ?? 'Subscribe';
    premiumFeatures.text = _featuresToText(data['premium_features']);
  }

  static String _featuresToText(dynamic features) {
    if (features == null) return '';
    if (features is List) return features.join('\n');
    return features.toString();
  }

  static List<String> _textToFeatures(String text) {
    return text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
  }

  Map<String, dynamic> toMap() {
    final premMonthly = double.tryParse(premiumPriceMonthly.text) ?? 4.99;
    final premDiscount = double.tryParse(premiumDiscountPct.text) ?? 0;

    return {
      'variant_name': variantName.text.trim(),
      'traffic_weight': int.tryParse(trafficWeight.text) ?? 50,
      'page_headline': pageHeadline.text.trim().isEmpty ? null : pageHeadline.text.trim(),
      'page_subheadline': pageSubheadline.text.trim().isEmpty ? null : pageSubheadline.text.trim(),
      'trial_text': trialText.text.trim().isEmpty ? null : trialText.text.trim(),
      'money_back_text': moneyBackText.text.trim().isEmpty ? null : moneyBackText.text.trim(),
      // Premium
      'premium_title': premiumTitle.text.trim(),
      'premium_subtitle': premiumSubtitle.text.trim().isEmpty ? null : premiumSubtitle.text.trim(),
      'premium_badge_text': premiumBadge.text.trim().isEmpty ? null : premiumBadge.text.trim(),
      'premium_price_monthly': premMonthly,
      'premium_price_yearly': _calcYearly(premMonthly, premDiscount),
      'premium_cta_monthly': premiumCtaMonthly.text.trim(),
      'premium_cta_yearly': premiumCtaYearly.text.trim(),
      'premium_features': _textToFeatures(premiumFeatures.text),
    };
  }
}

