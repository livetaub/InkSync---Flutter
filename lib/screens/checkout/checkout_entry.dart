/// Conditional import for checkout screens.
/// On web: loads the real Stripe-based checkout_screen.dart.
/// On mobile: loads a lightweight stub to avoid dart:html/dart:js.
export 'checkout_screen_mobile.dart'
    if (dart.library.html) 'checkout_screen.dart';
