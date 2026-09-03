import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_scaffold.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _profiles = [];

  @override
  void initState() {
    super.initState();
    _generateReports();
  }

  Future<void> _generateReports() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client.from('profiles').select();
      if (mounted) {
        setState(() {
          _profiles = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error generating reports: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _fmtMoney(double val) => NumberFormat.currency(symbol: '\$').format(val);
  String _fmtNum(num val) => NumberFormat.decimalPattern().format(val);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AdminScaffold(
        title: 'Reporting Engine',
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // --- REPORT CALCULATIONS ---
    
    // 1. Plan Distribution
    int freeCount = 0;
    int premiumCount = 0;
    int premiumFreeCount = 0;
    for (var p in _profiles) {
      final type = (p['account_type'] ?? 'free').toString().toLowerCase();
      if (type == 'premium') {
        premiumCount++;
      } else if (type == 'premium_free') {
        premiumFreeCount++;
      } else {
        freeCount++;
      }
    }
    final totalUsers = _profiles.length;
    final paidUsers = premiumCount; // Only actual paying subscribers
    final conversionRate = totalUsers == 0 ? 0.0 : (paidUsers / totalUsers) * 100;

    // 2. Projected MRR (Monthly Recurring Revenue)
    double mrr = 0.0;
    for (var p in _profiles) {
      if (p['account_status'] == 'active') {
        if (p['billing_cycle'] == 'monthly') {
          mrr += (p['locked_monthly_price'] ?? 0).toDouble();
        } else if (p['billing_cycle'] == 'yearly') {
          mrr += (p['locked_yearly_price'] ?? 0).toDouble() / 12.0;
        }
      }
    }

    // 3. Average Revenue Per User (ARPU)
    final arpu = paidUsers == 0 ? 0.0 : mrr / paidUsers;

    // 4. Lifetime Value (LTV)
    double totalLtv = 0.0;
    for (var p in _profiles) {
      totalLtv += (p['lifetime_value'] ?? 0).toDouble();
    }

    // 5. Engagement & Churn Risk
    final now = DateTime.now();
    int activeLast7Days = 0;
    int atRiskSubscribers = 0; // Paid users inactive for 30+ days
    
    for (var p in _profiles) {
      final lastActiveStr = p['last_active_at'];
      if (lastActiveStr != null) {
        final lastActive = DateTime.tryParse(lastActiveStr);
        if (lastActive != null) {
          final diff = now.difference(lastActive).inDays;
          if (diff <= 7) activeLast7Days++;
          
          final isPaid = p['account_type'] == 'premium' || p['account_type'] == 'premium_free';
          if (isPaid && diff >= 30) atRiskSubscribers++;
        }
      }
    }

    // 6. Infrastructure Liability (AI & Storage)
    int totalAiCredits = 0;
    int totalNotes = 0;
    for (var p in _profiles) {
      totalAiCredits += (p['ai_credits_used'] ?? 0) as int;
      totalNotes += (p['cached_notes_count'] ?? 0) as int;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;
    final padding = isMobile ? 12.0 : 32.0;

    return AdminScaffold(
      title: 'Reporting Engine',
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Live Analytics & Projections', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _generateReports,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Recalculate'),
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Analytics & Projections', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ElevatedButton.icon(
                      onPressed: _generateReports,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Recalculate'),
                    )
                  ],
                ),
              const SizedBox(height: 8),
              const Text('These reports are calculated on-the-fly using live data from the profiles table.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 32),

              // REVENUE ROW
              _sectionTitle('Revenue & Growth'),
              _buildReportRow(
                isMobile,
                [
                  _reportCard(
                    title: 'Projected MRR',
                    value: _fmtMoney(mrr),
                    subtitle: 'Monthly Recurring Revenue based on active subscriptions and grandfathered rates.',
                    icon: Icons.trending_up_rounded,
                    color: Colors.green,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'Total LTV Generated',
                    value: _fmtMoney(totalLtv),
                    subtitle: 'The aggregate Lifetime Value (total money spent) by all users in history.',
                    icon: Icons.account_balance_wallet_rounded,
                    color: Colors.blue,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'ARPU (Paid)',
                    value: _fmtMoney(arpu),
                    subtitle: 'Average Revenue Per User (calculated across paying subscribers only).',
                    icon: Icons.monetization_on_rounded,
                    color: Colors.teal,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // CONVERSION ROW
              _sectionTitle('User Conversion & Retention'),
              _buildReportRow(
                isMobile,
                [
                  _reportCard(
                    title: 'Paid Conversion Rate',
                    value: '${conversionRate.toStringAsFixed(1)}%',
                    subtitle: '$paidUsers paying subscriber${paidUsers == 1 ? '' : 's'} out of $totalUsers total users (excludes Premium Free grants).',
                    icon: Icons.pie_chart_rounded,
                    color: Colors.orange,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'Weekly Active Users (WAU)',
                    value: _fmtNum(activeLast7Days),
                    subtitle: 'Users who have logged in or synced a note within the last 7 days.',
                    icon: Icons.local_fire_department_rounded,
                    color: Colors.red,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'Churn Risk (Ghosted)',
                    value: _fmtNum(atRiskSubscribers),
                    subtitle: 'Paying subscribers who have NOT logged in within the last 30 days.',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.amber.shade700,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // INFRASTRUCTURE ROW
              _sectionTitle('Infrastructure Liabilities'),
              _buildReportRow(
                isMobile,
                [
                  _reportCard(
                    title: 'Total AI Credits Burned',
                    value: _fmtNum(totalAiCredits),
                    subtitle: 'Aggregate Gemini API usage. Use this to forecast your LLM token costs.',
                    icon: Icons.smart_toy_rounded,
                    color: Colors.deepPurple,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'Total Notes Synced',
                    value: _fmtNum(totalNotes),
                    subtitle: 'Total volume of active notes sitting in your Supabase database.',
                    icon: Icons.edit_document,
                    color: Colors.indigo,
                  ),
                  if (!isMobile) const SizedBox(width: 16),
                  _reportCard(
                    title: 'Plan Distribution',
                    value: '$freeCount Free / $premiumCount Premium / $premiumFreeCount Gifted',
                    subtitle: 'Free: no subscription. Premium: paying subscribers. Gifted: Premium Free grants.',
                    icon: Icons.layers_rounded,
                    color: Colors.cyan,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportRow(bool isMobile, List<Widget> cards) {
    if (isMobile) {
      return Column(
        children: cards.where((c) => c is! SizedBox).toList(),
      );
    } else {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: cards.map((c) => c is SizedBox ? c : Expanded(child: c)).toList(),
      );
    }
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
    );
  }

  Widget _reportCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(title, style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600, fontSize: 14))),
            ],
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A), letterSpacing: -1)),
          const SizedBox(height: 12),
          Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4)),
        ],
      ),
    );
  }
}
