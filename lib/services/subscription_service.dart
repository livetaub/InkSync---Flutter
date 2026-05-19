import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'auth_service.dart';

/// RevenueCat configuration
class RevenueCatConfig {
  // TODO: Replace with your actual RevenueCat API keys
  static const String appleApiKey = 'appl_REPLACE_WITH_YOUR_KEY';
  static const String googleApiKey = 'goog_REPLACE_WITH_YOUR_KEY';

  /// Entitlement ID configured in RevenueCat dashboard
  static const String premiumEntitlement = 'premium';

  /// Whether RevenueCat is properly configured
  static bool get isConfigured =>
      appleApiKey != 'appl_REPLACE_WITH_YOUR_KEY' &&
      googleApiKey != 'goog_REPLACE_WITH_YOUR_KEY';
}

/// Subscription plan model — populated from the Supabase `global_pricing` table
class SubscriptionPlan {
  final String planId;
  final double priceMonthly;
  final double priceYearly;
  final int notesLimit;
  final int aiCreditsLimit;

  const SubscriptionPlan({
    required this.planId,
    required this.priceMonthly,
    required this.priceYearly,
    required this.notesLimit,
    required this.aiCreditsLimit,
  });

  factory SubscriptionPlan.fromSupabase(Map<String, dynamic> data) {
    return SubscriptionPlan(
      planId: data['plan_id'] ?? 'free',
      priceMonthly: (data['price_monthly'] ?? 0).toDouble(),
      priceYearly: (data['price_yearly'] ?? 0).toDouble(),
      notesLimit: data['notes_limit'] ?? 0,
      aiCreditsLimit: data['ai_credits_limit'] ?? 0,
    );
  }
}

/// SubscriptionService — Manages native iOS/Android subscriptions via RevenueCat.
///
/// On mobile:
///   - Initializes RevenueCat SDK
///   - Pulls pricing from Supabase `global_pricing` for display
///   - Triggers native Apple/Google purchase flows
///   - Caches entitlement locally
///
/// On web: Not used (web uses Stripe checkout).
class SubscriptionService {
  static SubscriptionService? _instance;
  static SubscriptionService get instance => _instance ??= SubscriptionService._();

  SubscriptionService._();

  bool _isInitialized = false;
  bool _isPremium = false;
  String _currentPlan = 'free';
  Map<String, SubscriptionPlan> _plans = {};

  bool get isPremium => _isPremium;
  String get currentPlan => _currentPlan;
  Map<String, SubscriptionPlan> get plans => _plans;

  /// Initialize RevenueCat SDK. Call once on app start (mobile only).
  Future<void> initialize(AuthService authService) async {
    if (_isInitialized || kIsWeb) return;

    try {
      final apiKey = defaultTargetPlatform == TargetPlatform.iOS
          ? RevenueCatConfig.appleApiKey
          : RevenueCatConfig.googleApiKey;

      final configuration = PurchasesConfiguration(apiKey);

      // If user is logged in, identify them with their Supabase user ID
      // so purchases are linked across devices
      final userId = authService.currentUserId;
      if (userId != null) {
        configuration.appUserID = userId;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;

      // Check current entitlements
      await refreshEntitlementStatus();

      debugPrint('RevenueCat initialized. Premium: $_isPremium');
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
    }
  }

  /// Identify user after login (links anonymous purchases to account)
  Future<void> identifyUser(String userId) async {
    if (!_isInitialized) return;
    try {
      await Purchases.logIn(userId);
      await refreshEntitlementStatus();
    } catch (e) {
      debugPrint('Error identifying user in RevenueCat: $e');
    }
  }

  /// Log out of RevenueCat (resets to anonymous)
  Future<void> logoutUser() async {
    if (!_isInitialized) return;
    try {
      await Purchases.logOut();
      _isPremium = false;
      _currentPlan = 'free';
    } catch (e) {
      debugPrint('Error logging out of RevenueCat: $e');
    }
  }

  /// Fetch pricing from the Supabase `global_pricing` table.
  /// This is the single source of truth for plan details and display prices.
  Future<Map<String, SubscriptionPlan>> fetchPricingFromDatabase() async {
    try {
      final response = await Supabase.instance.client
          .from('global_pricing')
          .select();

      final plans = <String, SubscriptionPlan>{};
      for (final row in response) {
        final plan = SubscriptionPlan.fromSupabase(row);
        plans[plan.planId] = plan;
      }

      _plans = plans;
      return plans;
    } catch (e) {
      debugPrint('Error fetching pricing: $e');
      // Return sensible defaults if fetch fails
      return {
        'free': const SubscriptionPlan(
          planId: 'free',
          priceMonthly: 0,
          priceYearly: 0,
          notesLimit: 75,
          aiCreditsLimit: 0,
        ),
        'premium': const SubscriptionPlan(
          planId: 'premium',
          priceMonthly: 4.99,
          priceYearly: 49.99,
          notesLimit: 250,
          aiCreditsLimit: 100,
        ),
        'premium_pro': const SubscriptionPlan(
          planId: 'premium_pro',
          priceMonthly: 9.99,
          priceYearly: 99.99,
          notesLimit: 500,
          aiCreditsLimit: 200,
        ),
      };
    }
  }

  /// Refresh the current entitlement status from RevenueCat
  Future<void> refreshEntitlementStatus() async {
    if (!_isInitialized) return;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];

      _isPremium = entitlement != null;

      if (_isPremium && entitlement != null) {
        // Determine plan tier from product identifier
        final productId = entitlement.productIdentifier.toLowerCase();
        if (productId.contains('pro')) {
          _currentPlan = 'premium_pro';
        } else {
          _currentPlan = 'premium';
        }
      } else {
        _currentPlan = 'free';
      }
    } catch (e) {
      debugPrint('Error refreshing entitlement: $e');
    }
  }

  /// Get available packages (product offerings) from RevenueCat
  Future<List<Package>> getAvailablePackages() async {
    if (!_isInitialized) return [];

    try {
      final offerings = await Purchases.getOfferings();
      final current = offerings.current;
      if (current == null) return [];
      return current.availablePackages;
    } catch (e) {
      debugPrint('Error fetching offerings: $e');
      return [];
    }
  }

  /// Purchase a specific package
  /// Returns true if purchase succeeded, false otherwise.
  Future<bool> purchasePackage(Package package) async {
    if (!_isInitialized) return false;

    try {
      final result = await Purchases.purchasePackage(package);
      final customerInfo = result.customerInfo;
      final entitlement = customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];

      if (entitlement != null) {
        _isPremium = true;
        final productId = entitlement.productIdentifier.toLowerCase();
        _currentPlan = productId.contains('pro') ? 'premium_pro' : 'premium';

        // Also update the Supabase database directly for immediate sync
        await _updateSupabasePremiumStatus(true);
        return true;
      }
      return false;
    } on PurchasesErrorCode catch (e) {
      if (e == PurchasesErrorCode.purchaseCancelledError) {
        debugPrint('User cancelled purchase');
      } else {
        debugPrint('Purchase error: $e');
      }
      return false;
    } catch (e) {
      debugPrint('Purchase error: $e');
      return false;
    }
  }

  /// Restore previous purchases (e.g. after reinstall)
  Future<bool> restorePurchases() async {
    if (!_isInitialized) return false;

    try {
      final customerInfo = await Purchases.restorePurchases();
      final entitlement = customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];

      _isPremium = entitlement != null;
      if (_isPremium && entitlement != null) {
        final productId = entitlement.productIdentifier.toLowerCase();
        _currentPlan = productId.contains('pro') ? 'premium_pro' : 'premium';
        await _updateSupabasePremiumStatus(true);
      }

      return _isPremium;
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      return false;
    }
  }

  /// Get the active premium entitlement if any
  Future<EntitlementInfo?> getActiveEntitlement() async {
    if (!_isInitialized) return null;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      return customerInfo.entitlements.active[RevenueCatConfig.premiumEntitlement];
    } catch (e) {
      debugPrint('Error getting entitlement: $e');
      return null;
    }
  }

  /// Show the native OS manage subscriptions screen
  Future<void> showManageSubscriptions() async {
    if (!_isInitialized) return;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final managementUrl = customerInfo.managementURL;
      
      if (managementUrl != null && managementUrl.isNotEmpty) {
        final uri = Uri.parse(managementUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        }
      }
      
      // Fallback
      final fallbackUrl = defaultTargetPlatform == TargetPlatform.iOS
          ? 'https://apps.apple.com/account/subscriptions'
          : 'https://play.google.com/store/account/subscriptions';
      
      await launchUrl(Uri.parse(fallbackUrl), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error showing manage subscriptions: $e');
    }
  }

  /// Update Supabase user_settings after a successful purchase.
  /// This provides immediate premium access without waiting for the webhook.
  Future<void> _updateSupabasePremiumStatus(bool isPremium) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      await Supabase.instance.client
          .from('user_settings')
          .update({
            'is_premium': isPremium,
          })
          .eq('user_id', userId);

      // Also update profiles table account_type
      await Supabase.instance.client
          .from('profiles')
          .update({
            'account_type': _currentPlan,
          })
          .eq('id', userId);

      debugPrint('Supabase premium status updated: $isPremium');
    } catch (e) {
      debugPrint('Error updating Supabase premium: $e');
      // Non-critical — webhook will eventually sync this
    }
  }
}
