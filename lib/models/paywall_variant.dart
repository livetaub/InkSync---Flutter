/// Data models for the Paywall Content & Billing Configuration system.
///
/// [PaywallVariant] is the single source of truth for pricing, copy,
/// plan limits, and A/B test configuration. Fetched from the
/// `paywall_variants` Supabase table.

class PaywallVariant {
  final String id;
  final String variantName;
  final bool isActive;
  final int trafficWeight;

  // Page-level copy
  final String? pageHeadline;
  final String? pageSubheadline;

  // Per-tier content
  final TierContent free;
  final TierContent premium;

  // Shared copy
  final String? trialText;
  final String? moneyBackText;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PaywallVariant({
    required this.id,
    required this.variantName,
    this.isActive = true,
    this.trafficWeight = 50,
    this.pageHeadline,
    this.pageSubheadline,
    required this.free,
    required this.premium,
    this.trialText,
    this.moneyBackText,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Parse from Supabase row (flat columns → nested model)
  factory PaywallVariant.fromJson(Map<String, dynamic> json) {
    return PaywallVariant(
      id: json['id'] as String,
      variantName: json['variant_name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      trafficWeight: json['traffic_weight'] as int? ?? 50,
      pageHeadline: json['page_headline'] as String?,
      pageSubheadline: json['page_subheadline'] as String?,
      free: TierContent(
        title: json['free_title'] as String? ?? 'Free',
        subtitle: json['free_subtitle'] as String?,
        features: _parseFeatures(json['free_features']),
        badgeText: null,
        ctaMonthly: json['free_cta_text'] as String? ?? 'Continue for Free',
        ctaYearly: json['free_cta_text'] as String? ?? 'Continue for Free',
        priceMonthly: 0,
        priceYearly: 0,
        notesLimit: json['free_notes_limit'] as int? ?? 75,
        aiCredits: json['free_ai_credits'] as int? ?? 0,
      ),
      premium: TierContent(
        title: json['premium_title'] as String? ?? 'Premium',
        subtitle: json['premium_subtitle'] as String?,
        features: _parseFeatures(json['premium_features']),
        badgeText: json['premium_badge_text'] as String?,
        ctaMonthly: json['premium_cta_monthly'] as String? ?? 'Subscribe',
        ctaYearly: json['premium_cta_yearly'] as String? ?? 'Subscribe',
        priceMonthly: _parseDouble(json['premium_price_monthly']),
        priceYearly: _parseDouble(json['premium_price_yearly']),
        notesLimit: json['premium_notes_limit'] as int? ?? 250,
        aiCredits: json['premium_ai_credits'] as int? ?? 100,
      ),
      trialText: json['trial_text'] as String?,
      moneyBackText: json['money_back_text'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  /// Serialize to JSON for local caching
  Map<String, dynamic> toJson() => {
        'id': id,
        'variant_name': variantName,
        'is_active': isActive,
        'traffic_weight': trafficWeight,
        'page_headline': pageHeadline,
        'page_subheadline': pageSubheadline,
        'free_title': free.title,
        'free_subtitle': free.subtitle,
        'free_features': free.features,
        'free_cta_text': free.ctaMonthly,
        'free_notes_limit': free.notesLimit,
        'free_ai_credits': free.aiCredits,
        'premium_title': premium.title,
        'premium_subtitle': premium.subtitle,
        'premium_features': premium.features,
        'premium_badge_text': premium.badgeText,
        'premium_cta_monthly': premium.ctaMonthly,
        'premium_cta_yearly': premium.ctaYearly,
        'premium_price_monthly': premium.priceMonthly,
        'premium_price_yearly': premium.priceYearly,
        'premium_notes_limit': premium.notesLimit,
        'premium_ai_credits': premium.aiCredits,
        'trial_text': trialText,
        'money_back_text': moneyBackText,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  /// Get tier content by plan name
  TierContent getTier(String planId) {
    switch (planId) {
      case 'premium':
      case 'premium_free': // Admin-granted free tier — full Premium access
        return premium;
      case 'free':
      default:
        return free;
    }
  }

  /// Hardcoded fallback if all fetches fail (matches current production values)
  static PaywallVariant get fallback => PaywallVariant(
        id: 'fallback',
        variantName: 'Fallback',
        pageHeadline: 'Unlock your full potential',
        pageSubheadline: 'More notes. AI assist. Real-time collaboration.',
        free: const TierContent(
          title: 'Free',
          subtitle: 'For personal use',
          features: [
            '75 cross-platform notes',
            'Notes & checklists',
            'Link notes to calendar',
            'Filter by tags & colors',
            'Lock notes for privacy',
            'Web, iOS & Android',
          ],
          ctaMonthly: 'Continue for Free',
          ctaYearly: 'Continue for Free',
          priceMonthly: 0,
          priceYearly: 0,
          notesLimit: 75,
          aiCredits: 0,
        ),
        premium: const TierContent(
          title: 'Premium',
          subtitle: 'For power users',
          features: [
            'Unlimited notes',
            'AI writing assistant',
            'Real-time collaboration',
            'Priority support',
          ],
          badgeText: 'Most Popular',
          ctaMonthly: 'Subscribe',
          ctaYearly: 'Subscribe',
          priceMonthly: 4.99,
          priceYearly: 49.99,
          notesLimit: -1,
          aiCredits: -1,
        ),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static List<String> _parseFeatures(dynamic value) {
    if (value == null) return [];
    if (value is List) return value.map((e) => e.toString()).toList();
    return [];
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}

/// Content for a single subscription tier (Free or Premium).
class TierContent {
  final String title;
  final String? subtitle;
  final List<String> features;
  final String? badgeText;
  final String ctaMonthly;
  final String ctaYearly;
  final double priceMonthly;
  final double priceYearly;
  final int notesLimit;
  final int aiCredits;

  const TierContent({
    required this.title,
    this.subtitle,
    this.features = const [],
    this.badgeText,
    this.ctaMonthly = 'Subscribe',
    this.ctaYearly = 'Subscribe',
    this.priceMonthly = 0,
    this.priceYearly = 0,
    this.notesLimit = 75,
    this.aiCredits = 0,
  });
}

/// Plan limits extracted from a variant, used for feature enforcement.
class PlanLimits {
  final int notesLimit;
  final int aiCredits;

  const PlanLimits({
    required this.notesLimit,
    required this.aiCredits,
  });
}
