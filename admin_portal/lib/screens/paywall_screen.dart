import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/admin_scaffold.dart';

/// Paywall Management Screen
///
/// Two sections:
/// 1. Global Plan Limits — shared across all variants
/// 2. Variant list — compact cards with quick actions
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  bool _isLoading = true;
  bool _isSavingLimits = false;
  List<Map<String, dynamic>> _variants = [];
  Map<String, Map<String, int>> _analytics = {};
  /// Per-variant trigger source breakdown: variantId -> { trigger -> count }
  Map<String, Map<String, int>> _triggerSources = {};

  // Global limit controllers
  final _freeNotesLimit = TextEditingController();
  final _freeAiCredits = TextEditingController();
  final _premiumNotesLimit = TextEditingController();
  final _premiumAiCredits = TextEditingController();
  bool _isEditingLimits = false;


  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _freeNotesLimit.dispose();
    _freeAiCredits.dispose();
    _premiumNotesLimit.dispose();
    _premiumAiCredits.dispose();

    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final variants = await Supabase.instance.client
          .from('paywall_variants')
          .select()
          .order('created_at', ascending: true);

      // Fetch global pricing
      final pricing = await Supabase.instance.client
          .from('global_pricing')
          .select();

      // Fetch analytics summary per variant (include metadata for trigger_source)
      final events = await Supabase.instance.client
          .from('paywall_events')
          .select('variant_id, event_type, metadata');

      final analytics = <String, Map<String, int>>{};
      final triggers = <String, Map<String, int>>{};
      for (final event in events) {
        final vid = event['variant_id'] as String;
        final type = event['event_type'] as String;
        analytics.putIfAbsent(vid, () => {});
        analytics[vid]![type] = (analytics[vid]![type] ?? 0) + 1;

        // Parse trigger_source from metadata on paywall_viewed events
        if (type == 'paywall_viewed') {
          final meta = event['metadata'];
          if (meta is Map) {
            final src = (meta['trigger_source'] ?? 'unknown').toString();
            triggers.putIfAbsent(vid, () => {});
            triggers[vid]![src] = (triggers[vid]![src] ?? 0) + 1;
          }
        }
      }

      if (mounted) {
        final list = List<Map<String, dynamic>>.from(variants);

        // Populate text controllers from global_pricing
        for (final row in pricing) {
          final planId = row['plan_id'] as String;
          if (planId == 'free') {
            _freeNotesLimit.text = (row['notes_limit'] ?? 75).toString();
            _freeAiCredits.text = (row['ai_credits_limit'] ?? 0).toString();
          } else if (planId == 'premium') {
            _premiumNotesLimit.text = (row['notes_limit'] ?? 250).toString();
            _premiumAiCredits.text = (row['ai_credits_limit'] ?? 100).toString();
          }
        }

        setState(() {
          _variants = list;
          _analytics = analytics;
          _triggerSources = triggers;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[PaywallScreen] Error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int get _activeCount => _variants.where((v) => v['is_active'] == true).length;

  // ─── Global Limits ──────────────────────────────────────────────

  Future<void> _saveGlobalLimits() async {
    setState(() => _isSavingLimits = true);
    try {
      final freeNotes = int.tryParse(_freeNotesLimit.text) ?? 75;
      final freeAi = int.tryParse(_freeAiCredits.text) ?? 0;
      final premiumNotes = int.tryParse(_premiumNotesLimit.text) ?? 250;
      final premiumAi = int.tryParse(_premiumAiCredits.text) ?? 100;

      await Supabase.instance.client
          .from('global_pricing')
          .update({
            'notes_limit': freeNotes,
            'ai_credits_limit': freeAi,
          })
          .eq('plan_id', 'free');

      await Supabase.instance.client
          .from('global_pricing')
          .update({
            'notes_limit': premiumNotes,
            'ai_credits_limit': premiumAi,
          })
          .eq('plan_id', 'premium');

      _showSnack('Global plan limits updated successfully.', const Color(0xFF10B981));
      setState(() => _isEditingLimits = false);
      _fetchData();
    } catch (e) {
      _showSnack('Error saving limits: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _isSavingLimits = false);
    }
  }

  // ─── Variant Actions ────────────────────────────────────────────

  Future<void> _toggleActive(Map<String, dynamic> variant) async {
    final isActive = variant['is_active'] as bool;
    if (isActive && _activeCount <= 1) {
      _showSnack('Cannot deactivate the last active variant.', Colors.orange);
      return;
    }

    try {
      await Supabase.instance.client
          .from('paywall_variants')
          .update({'is_active': !isActive})
          .eq('id', variant['id']);
      _showSnack(!isActive ? 'Variant activated.' : 'Variant deactivated.', const Color(0xFF10B981));
      _fetchData();
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    if (variant['is_active'] == true && _activeCount <= 1) {
      _showSnack('Cannot delete the last active variant.', Colors.orange);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Variant?'),
        content: Text('Delete "${variant['variant_name']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client.from('paywall_variants').delete().eq('id', variant['id']);
      _showSnack('Variant deleted.', const Color(0xFF10B981));
      _fetchData();
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  Future<void> _duplicateVariant(Map<String, dynamic> variant) async {
    final newData = Map<String, dynamic>.from(variant);
    newData.remove('id');
    newData.remove('created_at');
    newData.remove('updated_at');
    newData['variant_name'] = '${variant['variant_name']} (Copy)';
    newData['is_active'] = false;
    newData['traffic_weight'] = 0;

    try {
      await Supabase.instance.client.from('paywall_variants').insert(newData);
      _showSnack('Variant duplicated (inactive, 0% traffic).', const Color(0xFF10B981));
      _fetchData();
    } catch (e) {
      _showSnack('Error: $e', Colors.red);
    }
  }

  void _showSnack(String msg, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: color),
      );
    }
  }

  // ─── Build ──────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Paywall & A/B Testing',
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlobalLimitsCard(),
                  const SizedBox(height: 32),
                  _buildVariantSection(),
                ],
              ),
            ),
    );
  }

  // ─── Global Limits Card ─────────────────────────────────────────

  Widget _buildGlobalLimitsCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.tune_rounded, color: Color(0xFF10B981), size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Global Plan Limits', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
                    SizedBox(height: 2),
                    Text(
                      'These limits apply to all users across the system.',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Side-by-side tier columns
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _limitTierColumn('Free Tier', Icons.notes_rounded, const Color(0xFF64748B), _freeNotesLimit, _freeAiCredits)),
              const SizedBox(width: 20),
              Expanded(child: _limitTierColumn('Premium Tier', Icons.diamond_rounded, const Color(0xFF10B981), _premiumNotesLimit, _premiumAiCredits)),
            ],
          ),

          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_isEditingLimits) ...[
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _isEditingLimits = false;
                      _fetchData(); // reset edits
                    });
                  },
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isSavingLimits ? null : _saveGlobalLimits,
                  icon: _isSavingLimits
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save_rounded, size: 18),
                  label: const Text('Save Limits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ] else
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() => _isEditingLimits = true);
                  },
                  icon: const Icon(Icons.edit_rounded, size: 18),
                  label: const Text('Edit Limits'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E293B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _limitTierColumn(String label, IconData icon, Color color, TextEditingController notesCtrl, TextEditingController aiCtrl) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            ],
          ),
          const SizedBox(height: 16),
          _limitField('Notes Limit', notesCtrl),
          const SizedBox(height: 12),
          _limitField('AI Credits / month', aiCtrl),
        ],
      ),
    );
  }

  Widget _limitField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          enabled: _isEditingLimits,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
            ),
            filled: true,
            fillColor: _isEditingLimits ? Colors.white : const Color(0xFFF8FAFC),
          ),
        ),
      ],
    );
  }

  // ─── Variant Section ────────────────────────────────────────────

  Widget _buildVariantSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Paywall Variants', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B))),
                SizedBox(height: 4),
                Text('Manage copy, pricing, and A/B test traffic.', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => context.go('/paywall/new'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('New Variant'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTrafficSummary(),
        const SizedBox(height: 20),
        ..._variants.map((v) => _buildVariantCard(v)),
      ],
    );
  }

  Widget _buildTrafficSummary() {
    final active = _variants.where((v) => v['is_active'] == true).toList();
    final totalWeight = active.fold<int>(0, (sum, v) => sum + (v['traffic_weight'] as int? ?? 0));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 12),
          Text(
            '${active.length} active variant${active.length == 1 ? '' : 's'}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1E293B)),
          ),
          if (active.isNotEmpty) ...[
            const SizedBox(width: 12),
            Text('·', style: TextStyle(color: Colors.grey.shade400, fontSize: 16)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                active.map((v) {
                  final w = v['traffic_weight'] as int? ?? 0;
                  final pct = totalWeight > 0 ? (w / totalWeight * 100).toStringAsFixed(0) : '0';
                  return '${v['variant_name']}: $pct%';
                }).join('   ·   '),
                style: const TextStyle(color: Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantCard(Map<String, dynamic> variant) {
    final isActive = variant['is_active'] as bool? ?? false;
    final vid = variant['id'] as String;
    final stats = _analytics[vid] ?? {};
    final views = stats['paywall_viewed'] ?? 0;
    final clicks = stats['cta_clicked'] ?? 0;
    final conversions = stats['checkout_completed'] ?? 0;
    final convRate = views > 0 ? (conversions / views * 100).toStringAsFixed(1) : '0.0';
    final triggerMap = _triggerSources[vid] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? const Color(0xFF10B981).withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.06),
          width: isActive ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Status + Name
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? const Color(0xFF10B981) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              variant['variant_name'] as String? ?? 'Unnamed',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Weight: ${variant['traffic_weight'] ?? 0}  ·  \$${variant['premium_price_monthly'] ?? '?'}/mo',
                              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Analytics
                Expanded(
                  flex: 3,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _miniStat('Views', views),
                      const SizedBox(width: 20),
                      _miniStat('Clicks', clicks),
                      const SizedBox(width: 20),
                      _miniStat('Conv.', conversions),
                      const SizedBox(width: 20),
                      _miniStat('Rate', '$convRate%'),
                    ],
                  ),
                ),

                // Actions
                Expanded(
                  flex: 2,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _actionIcon(Icons.edit_rounded, 'Edit', const Color(0xFF3B82F6), () => context.go('/paywall/edit/${variant['id']}')),
                      _actionIcon(Icons.copy_rounded, 'Duplicate', const Color(0xFF64748B), () => _duplicateVariant(variant)),
                      _actionIcon(
                        isActive ? Icons.pause_circle_rounded : Icons.play_circle_rounded,
                        isActive ? 'Deactivate' : 'Activate',
                        isActive ? Colors.orange : const Color(0xFF10B981),
                        () => _toggleActive(variant),
                      ),
                      _actionIcon(Icons.delete_outline_rounded, 'Delete', const Color(0xFFEF4444), () => _deleteVariant(variant)),
                    ],
                  ),
                ),
              ],
            ),

            // Trigger Source Breakdown
            if (triggerMap.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.black.withValues(alpha: 0.04)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_rounded, size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 8),
                    const Text('Triggers:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: triggerMap.entries.map((e) {
                          return _triggerChip(e.key, e.value, views);
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String label, dynamic value) {
    return Column(
      children: [
        Text('$value', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _actionIcon(IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  static const _triggerLabels = {
    'signup': 'Signup',
    'ai_assist': 'AI Assist',
    'note_limit': 'Note Limit',
    'collaboration': 'Collab',
    'menu': 'Menu',
    'feature_gate': 'Feature Gate',
    'unknown': 'Unknown',
  };

  static const _triggerColors = {
    'signup': Color(0xFF6366F1),
    'ai_assist': Color(0xFFF59E0B),
    'note_limit': Color(0xFFEF4444),
    'collaboration': Color(0xFF3B82F6),
    'menu': Color(0xFF64748B),
    'feature_gate': Color(0xFF8B5CF6),
    'unknown': Color(0xFFCBD5E1),
  };

  Widget _triggerChip(String source, int count, int totalViews) {
    final label = _triggerLabels[source] ?? source;
    final color = _triggerColors[source] ?? const Color(0xFF94A3B8);
    final pct = totalViews > 0 ? (count / totalViews * 100).toStringAsFixed(0) : '0';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        '$label: $count ($pct%)',
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}
