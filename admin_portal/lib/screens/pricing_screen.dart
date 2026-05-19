import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/admin_scaffold.dart';

class PricingScreen extends StatefulWidget {
  const PricingScreen({super.key});

  @override
  State<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends State<PricingScreen> {
  bool _isLoading = true;
  bool _isEditing = false;
  bool _isSaving = false;

  // Controllers mapped by plan_id and field name
  final Map<String, Map<String, TextEditingController>> _controllers = {
    'free': {
      'notes_limit': TextEditingController(),
      'ai_credits_limit': TextEditingController(),
    },
    'premium': {
      'price_monthly': TextEditingController(),
      'price_yearly': TextEditingController(),
      'notes_limit': TextEditingController(),
      'ai_credits_limit': TextEditingController(),
    },
    'premium_pro': {
      'price_monthly': TextEditingController(),
      'price_yearly': TextEditingController(),
      'notes_limit': TextEditingController(),
      'ai_credits_limit': TextEditingController(),
    },
  };

  @override
  void initState() {
    super.initState();
    _fetchPricing();
  }

  Future<void> _fetchPricing() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('global_pricing')
          .select();
      
      for (final row in response) {
        final planId = row['plan_id'] as String;
        if (_controllers.containsKey(planId)) {
          if (row['price_monthly'] != null && _controllers[planId]!['price_monthly'] != null) {
            _controllers[planId]!['price_monthly']!.text = row['price_monthly'].toString();
          }
          if (row['price_yearly'] != null && _controllers[planId]!['price_yearly'] != null) {
            _controllers[planId]!['price_yearly']!.text = row['price_yearly'].toString();
          }
          if (row['notes_limit'] != null) {
            _controllers[planId]!['notes_limit']!.text = row['notes_limit'].toString();
          }
          if (row['ai_credits_limit'] != null) {
            _controllers[planId]!['ai_credits_limit']!.text = row['ai_credits_limit'].toString();
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching pricing: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePricing() async {
    setState(() => _isSaving = true);
    try {
      final updates = [
        {
          'plan_id': 'free',
          'notes_limit': int.tryParse(_controllers['free']!['notes_limit']!.text) ?? 75,
          'ai_credits_limit': int.tryParse(_controllers['free']!['ai_credits_limit']!.text) ?? 0,
        },
        {
          'plan_id': 'premium',
          'price_monthly': double.tryParse(_controllers['premium']!['price_monthly']!.text) ?? 4.99,
          'price_yearly': double.tryParse(_controllers['premium']!['price_yearly']!.text) ?? 49.99,
          'notes_limit': int.tryParse(_controllers['premium']!['notes_limit']!.text) ?? 250,
          'ai_credits_limit': int.tryParse(_controllers['premium']!['ai_credits_limit']!.text) ?? 100,
        },
        {
          'plan_id': 'premium_pro',
          'price_monthly': double.tryParse(_controllers['premium_pro']!['price_monthly']!.text) ?? 9.99,
          'price_yearly': double.tryParse(_controllers['premium_pro']!['price_yearly']!.text) ?? 99.99,
          'notes_limit': int.tryParse(_controllers['premium_pro']!['notes_limit']!.text) ?? 500,
          'ai_credits_limit': int.tryParse(_controllers['premium_pro']!['ai_credits_limit']!.text) ?? 200,
        }
      ];

      for (var update in updates) {
        await Supabase.instance.client
            .from('global_pricing')
            .update(update)
            .eq('plan_id', update['plan_id'] as String);
      }

      if (mounted) {
        setState(() => _isEditing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing successfully updated in database.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint('Error saving pricing: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'Global Pricing Configuration',
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Manage Global Pricing Tiers', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      SizedBox(height: 8),
                      Text('Values are synced directly to the global_pricing database table.', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                  if (!_isEditing)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _isEditing = true),
                      icon: const Icon(Icons.edit_rounded),
                      label: const Text('Edit Pricing'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF0F172A),
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      ),
                    )
                  else
                    Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() => _isEditing = false);
                            _fetchPricing(); // Reset values
                          },
                          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _savePricing,
                          icon: _isSaving 
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                              : const Icon(Icons.save_rounded),
                          label: const Text('Save & Lock'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                          ),
                        ),
                      ],
                    )
                ],
              ),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _planColumn('Free', 'free', false),
                  const SizedBox(width: 24),
                  _planColumn('Premium', 'premium', true),
                  const SizedBox(width: 24),
                  _planColumn('Premium Pro', 'premium_pro', true),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _planColumn(String title, String planId, bool isPaid) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isEditing ? const Color(0xFF3B82F6).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
            width: _isEditing ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                if (_isEditing) const Icon(Icons.edit_rounded, size: 16, color: Color(0xFF3B82F6)),
              ],
            ),
            const SizedBox(height: 24),
            if (isPaid) ...[
              _buildField('Monthly Price (\$)', _controllers[planId]!['price_monthly']!),
              const SizedBox(height: 16),
              _buildField('Yearly Price (\$)', _controllers[planId]!['price_yearly']!),
              const SizedBox(height: 16),
            ],
            _buildField('Notes Limit', _controllers[planId]!['notes_limit']!),
            const SizedBox(height: 16),
            _buildField('AI Credits Limit', _controllers[planId]!['ai_credits_limit']!),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller) {
    return TextField(
      controller: controller,
      readOnly: !_isEditing,
      enabled: _isEditing,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: !_isEditing,
        fillColor: _isEditing ? Colors.white : const Color(0xFFF8FAFC),
      ),
    );
  }
}
