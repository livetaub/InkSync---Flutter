// Supabase Configuration
//
// Replace the placeholder values with your actual Supabase project details.
//
// To get these values:
// 1. Go to https://supabase.com and open your project
// 2. Navigate to Settings > API
// 3. Copy the "Project URL" and "anon public" key

class SupabaseConfig {
  /// Your Supabase project URL
  static const String supabaseUrl = 'https://bgzogfldvbdaoajlxjhf.supabase.co';

  /// Your Supabase anon/public key (JWT format)
  /// This is safe to expose in client-side code
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJnem9nZmxkdmJkYW9hamx4amhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg1MzQ4OTIsImV4cCI6MjA4NDExMDg5Mn0.Vthud-MOyDAL6NUuHHhGyDlVmCD5nG3B70Q4fQddtoI';

  /// Whether Supabase is properly configured
  static bool get isConfigured =>
      supabaseUrl != 'YOUR_SUPABASE_URL' &&
      supabaseAnonKey != 'YOUR_SUPABASE_ANON_KEY';

  /// Deep link scheme for OAuth callbacks (mobile)
  static const String deepLinkScheme = 'io.supabase.inksync';

  /// OAuth callback URL for mobile
  static const String authCallbackUrl = '$deepLinkScheme://login-callback/';

  /// Web Client ID for Google Sign-In (needed for native Android OAuth)
  static const String googleWebClientId =
      '624897890206-vdeq2lo0m7r7ffun4glupnd17p1t0pn1.apps.googleusercontent.com';

  /// iOS Client ID for Google Sign-In (needed for native iOS OAuth)
  static const String googleIosClientId =
      '624897890206-6b8sbg21sgro6r7co5ocf02tgsben6hk.apps.googleusercontent.com';
}
