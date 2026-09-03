import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../widgets/admin_scaffold.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  double _totalRevenue = 0.0;
  int _totalNotes = 0;
  List<FlSpot> _growthSpots = [];
  double _maxX = 0;
  double _maxY = 0;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: true)
          .limit(500);
      
      final profiles = List<Map<String, dynamic>>.from(response);

      int users = profiles.length;
      double revenue = 0.0;
      int notes = 0;

      // Group users by Day for the chart
      Map<String, int> dailySignups = {};

      for (var p in profiles) {
        // Revenue
        if (p['account_status'] == 'active') {
          if (p['billing_cycle'] == 'monthly') {
            revenue += (p['locked_monthly_price'] ?? 0).toDouble();
          } else if (p['billing_cycle'] == 'yearly') {
            revenue += (p['locked_yearly_price'] ?? 0).toDouble() / 12.0;
          }
        }
        
        // Notes
        notes += (p['cached_notes_count'] ?? 0) as int;

        // Chart Data
        final createdAtStr = p['created_at'];
        if (createdAtStr != null) {
          final dt = DateTime.tryParse(createdAtStr);
          if (dt != null) {
            final dayStr = DateFormat('yyyy-MM-dd').format(dt);
            dailySignups[dayStr] = (dailySignups[dayStr] ?? 0) + 1;
          }
        }
      }

      // Build cumulative chart spots
      List<FlSpot> spots = [];
      if (dailySignups.isNotEmpty) {
        final sortedKeys = dailySignups.keys.toList()..sort();
        int cumulative = 0;
        double xIndex = 0;
        
        for (final key in sortedKeys) {
          cumulative += dailySignups[key]!;
          spots.add(FlSpot(xIndex, cumulative.toDouble()));
          xIndex++;
        }
        _maxX = xIndex > 0 ? xIndex - 1 : 0;
        _maxY = cumulative.toDouble() * 1.2; // 20% headroom
      } else {
        spots = [const FlSpot(0, 0)];
        _maxX = 1;
        _maxY = 10;
      }

      if (mounted) {
        setState(() {
          _totalUsers = users;
          _totalRevenue = revenue;
          _totalNotes = notes;
          _growthSpots = spots;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 700;
    final padding = isMobile ? 16.0 : 32.0;

    return AdminScaffold(
      title: 'Overview Dashboard',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _isLoading ? null : _fetchDashboardData,
          tooltip: 'Refresh Dashboard',
        ),
      ],
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            isMobile
            ? Column(
                children: [
                  Row(children: [_statCard('Total Users', NumberFormat.decimalPattern().format(_totalUsers), Icons.people_rounded)]),
                  const SizedBox(height: 16),
                  Row(children: [_statCard('Monthly Revenue', NumberFormat.currency(symbol: '\$').format(_totalRevenue), Icons.attach_money_rounded)]),
                  const SizedBox(height: 16),
                  Row(children: [_statCard('Notes Synced', NumberFormat.decimalPattern().format(_totalNotes), Icons.notes_rounded)]),
                ],
              )
            : Row(
                children: [
                  _statCard('Total Users', NumberFormat.decimalPattern().format(_totalUsers), Icons.people_rounded),
                  const SizedBox(width: 24),
                  _statCard('Monthly Revenue', NumberFormat.currency(symbol: '\$').format(_totalRevenue), Icons.attach_money_rounded),
                  const SizedBox(width: 24),
                  _statCard('Notes Synced', NumberFormat.decimalPattern().format(_totalNotes), Icons.notes_rounded),
                ],
              ),
            const SizedBox(height: 32),
            const Text('Cumulative User Growth', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: _growthSpots.isEmpty || _totalUsers == 0
                    ? const Center(child: Text('Not enough data to render chart.', style: TextStyle(color: Colors.grey)))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: (_maxY / 5) > 0 ? (_maxY / 5) : 1,
                            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withValues(alpha: 0.1), strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), // Hide X axis labels for simplicity
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 40,
                                getTitlesWidget: (value, meta) => Text(value.toInt().toString(), style: const TextStyle(color: Colors.grey, fontSize: 12)),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          minX: 0,
                          maxX: _maxX,
                          minY: 0,
                          maxY: _maxY == 0 ? 10 : _maxY,
                          lineBarsData: [
                            LineChartBarData(
                              spots: _growthSpots,
                              isCurved: true,
                              color: const Color(0xFF3B82F6),
                              barWidth: 4,
                              isStrokeCapRound: true,
                              dotData: const FlDotData(show: false),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF3B82F6).withValues(alpha: 0.3),
                                    const Color(0xFF3B82F6).withValues(alpha: 0.0),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF0F172A)),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 28, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
