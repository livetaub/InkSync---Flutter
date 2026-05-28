// Stripe Configuration
//
// Replace placeholder values with your actual Stripe keys.
//
// To get these values:
// 1. Go to https://dashboard.stripe.com/developers
// 2. Copy the "Publishable key" (pk_test_... or pk_live_...)
// 3. The Secret Key is used ONLY in your Supabase Edge Functions (never in client code)

class StripeConfig {
  /// Stripe Publishable Key (safe for client-side)
  /// Replace with your actual key from Stripe Dashboard > Developers > API Keys
  static const String publishableKey = 'pk_live_51SlzeN3vVetXJOaZ2pLmLMgiRVD7jLS4GKmDcC3rhz3zm4tUZvSAYTV5LBCjvXDdlIPyxAQGdFGP5HUkDKhzKaKb00BcuO3T7Q';

  /// Supabase Edge Function base URL for Stripe operations
  static const String subscriptionFunctionUrl =
      'https://bgzogfldvbdaoajlxjhf.supabase.co/functions/v1/create-subscription';

  /// Success redirect URL after Stripe Checkout
  static const String successUrl = 'https://app.inksyncnote.com/checkout-success';

  /// Cancel redirect URL if user abandons checkout
  static const String cancelUrl = 'https://inksyncnote.com/pricing';

  /// Whether Stripe is properly configured
  static bool get isConfigured =>
      publishableKey != 'pk_test_REPLACE_WITH_YOUR_KEY';
}
