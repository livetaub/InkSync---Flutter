import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/subscription_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/platform_helper.dart' as platform;
import '../../config/theme.dart';
import 'mobile_paywall_screen.dart';
import '../checkout/android_checkout_screen.dart';

class SubscriptionScreen extends StatefulWidget {
  final bool isDialog;

  const SubscriptionScreen({super.key, this.isDialog = false});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  String _currentPlan = 'Free';
  String _status = 'Inactive';
  String? _periodEnd;
  String? _origin;

  @override
  void initState() {
    super.initState();
    _fetchSubscriptionStatus();
  }

  Future<void> _fetchSubscriptionStatus() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('account_type, subscription_status, subscription_period_end, subscription_origin')
            .eq('id', user.id)
            .single();

        setState(() {
          _currentPlan = res['account_type'] ?? 'Free';
          _status = res['subscription_status'] ?? 'Inactive';
          if (_currentPlan.toLowerCase() == 'free') {
            _status = 'Active';
          }
          _periodEnd = res['subscription_period_end'];
          _origin = res['subscription_origin'];
        });
      }
      
      // Still refresh RevenueCat on mobile just to sync local state if needed
      if (!kIsWeb) {
        await SubscriptionService.instance.refreshEntitlementStatus();
      }
    } catch (e) {
      debugPrint('Error fetching subscription: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _launchUrl(String url) async {
    if (kIsWeb) {
      platform.setLocationHref(url);
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link.')),
        );
      }
    }
  }

  Future<void> _handleManageSubscription() async {
    try {
      if (_origin == 'stripe' || (_origin == null && _currentPlan != 'Free')) {
        // Stripe Customer Portal
        final res = await Supabase.instance.client.functions.invoke('create-portal-session');
        final data = res.data;
        if (data != null && data['url'] != null) {
          _launchUrl(data['url']);
        }
      } else if (_origin == 'appStore') {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
          _launchUrl('https://apps.apple.com/account/subscriptions');
        } else {
          _showCrossPlatformAlert(
            'Apple',
            'https://apps.apple.com/account/subscriptions',
            'To cancel or change your plan, please manage your billing from the Settings app on an iPhone/iPad, or click the link below if you are on a desktop computer (Mac/Windows).'
          );
        }
      } else if (_origin == 'playStore') {
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
          _launchUrl('https://play.google.com/store/account/subscriptions');
        } else {
          _showCrossPlatformAlert(
            'Google Play',
            'https://play.google.com/store/account/subscriptions',
            'To cancel or change your plan, please manage your billing from the Google Play Store on an Android device, or click the link below.'
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open billing management: $e')),
      );
    }
  }

  void _showCrossPlatformAlert(String storeName, String url, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Managed by $storeName'),
        content: Text(
          'Your subscription was purchased through $storeName and is securely managed by them.\n\n$message'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _launchUrl(url);
            },
            child: const Text('Open Desktop Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUpgrade() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const MobilePaywallScreen(),
      ),
    );
    _fetchSubscriptionStatus(); // Refresh status after paywall closes
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final content = Column(
      children: [
        if (widget.isDialog)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Manage Subscription',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        if (widget.isDialog) const Divider(height: 1),
        Expanded(
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  // Current Plan Card
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CURRENT PLAN',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _currentPlan.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Icon(
                              _status == 'active' || _status == 'Active' ? Icons.check_circle : Icons.info_outline,
                              color: _status == 'active' || _status == 'Active' ? Colors.green : Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Status: $_status',
                              style: const TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                        if (_periodEnd != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Renews / Expires on: ${DateTime.parse(_periodEnd!).toLocal().toString().split(' ')[0]}',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Actions
                  if (_currentPlan == 'Free' || _currentPlan.toLowerCase() == 'free')
                    ElevatedButton.icon(
                      onPressed: _handleUpgrade,
                      icon: const Icon(Icons.star),
                      label: const Text('Upgrade Plan'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _handleManageSubscription,
                          icon: const Icon(Icons.receipt_long),
                          label: const Text('View Billing History & Manage'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _handleManageSubscription, // Portal/Native handles cancellation
                          icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                          label: const Text('Cancel Subscription', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                ],
              ),
        ),
      ],
    );

    if (widget.isDialog) {
      return content;
    }
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Manage Subscription'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: content,
    );
  }
}
