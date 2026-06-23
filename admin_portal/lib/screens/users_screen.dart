import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../widgets/admin_scaffold.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  // Controllers
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  
  // Sorting state
  int _sortColumnIndex = 1;
  int _sortDataIndex = 0;
  bool _isSortAscending = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  @override
  void dispose() {
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .order('created_at', ascending: false);
      
      if (mounted) {
        setState(() {
          _users = List<Map<String, dynamic>>.from(response);
          _applyFiltersAndSort();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('[UsersScreen] Error fetching users: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFiltersAndSort() {
    // 1. Filter
    if (_searchQuery.isEmpty) {
      _filteredUsers = List.from(_users);
    } else {
      final query = _searchQuery.toLowerCase();
      _filteredUsers = _users.where((u) {
        final email = (u['email'] ?? '').toString().toLowerCase();
        final id = (u['id'] ?? '').toString().toLowerCase();
        return email.contains(query) || id.contains(query);
      }).toList();
    }

    // 2. Sort
    _filteredUsers.sort((a, b) {
      dynamic valA;
      dynamic valB;

      switch (_sortDataIndex) {
        case 0: // ID
          valA = a['id']; valB = b['id']; break;
        case 1: // Email
          valA = a['email']; valB = b['email']; break;
        case 2: // Status
          valA = a['account_status']; valB = b['account_status']; break;
        case 3: // Type
          valA = a['account_type']; valB = b['account_type']; break;
        case 4: // Billing Cycle
          valA = a['billing_cycle']; valB = b['billing_cycle']; break;
        case 5: // LTV
          valA = (a['lifetime_value'] ?? 0).toDouble(); valB = (b['lifetime_value'] ?? 0).toDouble(); break;
        case 6: // AI Credits
          valA = a['ai_credits_used'] ?? 0; valB = b['ai_credits_used'] ?? 0; break;
        case 7: // AI Cost
          valA = _calcAiCost(a); valB = _calcAiCost(b); break;
        case 8: // Notes Count
          valA = a['cached_notes_count'] ?? 0; valB = b['cached_notes_count'] ?? 0; break;
        case 9: // Storage Bytes
          valA = a['cached_storage_bytes'] ?? 0; valB = b['cached_storage_bytes'] ?? 0; break;
        case 10: // Last Active
          valA = a['last_active_at'] ?? ''; valB = b['last_active_at'] ?? ''; break;
        case 11: // Created At
          valA = a['created_at'] ?? ''; valB = b['created_at'] ?? ''; break;
        default:
          valA = ''; valB = '';
      }

      // Handle nulls and comparisons
      if (valA == null && valB == null) return 0;
      if (valA == null) return _isSortAscending ? 1 : -1;
      if (valB == null) return _isSortAscending ? -1 : 1;

      int result;
      if (valA is num && valB is num) {
        result = valA.compareTo(valB);
      } else {
        result = valA.toString().compareTo(valB.toString());
      }
      return _isSortAscending ? result : -result;
    });
  }

  void _onSort(int columnIndex, bool ascending) {
    setState(() {
      _sortColumnIndex = columnIndex;
      _sortDataIndex = columnIndex - 1; // Offset for Actions column at index 0
      _isSortAscending = ascending;
      _applyFiltersAndSort();
    });
  }

  String _formatDate(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'N/A';
    try {
      return DateFormat('yyyy-MM-dd HH:mm').format(DateTime.parse(isoDate));
    } catch (_) {
      return 'Invalid';
    }
  }

  String _formatCurrency(dynamic value) {
    if (value == null) return '\$0.00';
    return NumberFormat.currency(symbol: '\$').format(value);
  }

  String _formatBytes(dynamic bytes) {
    if (bytes == null || bytes == 0) return '0 B';
    final b = bytes is int ? bytes : int.tryParse(bytes.toString()) ?? 0;
    if (b < 1024) return '$b B';
    if (b < 1048576) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1048576).toStringAsFixed(2)} MB';
  }

  /// Calculate estimated AI cost from tracked token usage
  double _calcAiCost(Map<String, dynamic> user) {
    final inputTokens = (user['ai_input_tokens'] ?? 0) as num;
    final outputTokens = (user['ai_output_tokens'] ?? 0) as num;
    // Gemini 2.5 Flash pricing: $0.15/1M input, $0.60/1M output
    return (inputTokens.toDouble() * 0.00000015) + (outputTokens.toDouble() * 0.0000006);
  }

  Future<void> _grantPremiumFree(String userId) async {
    try {
      await Supabase.instance.client.from('profiles').update({
        'account_type': 'premium_free',
      }).eq('id', userId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Granted Premium Free access!'), backgroundColor: Colors.green));
        _fetchUsers();
      }
    } catch (e) {
      debugPrint('[UsersScreen] Error granting premium free: $e');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('An error occurred. Please try again.'), backgroundColor: Colors.red));
    }
  }

  Widget _planBadge(String? accountType) {
    final type = accountType ?? 'free';
    Color color;
    String label;
    switch (type) {
      case 'premium_free':
        color = const Color(0xFF8B5CF6); // Purple
        label = 'PREMIUM FREE';
        break;
      case 'premium':
        color = const Color(0xFF3B82F6); // Blue
        label = 'PREMIUM';
        break;
      default:
        color = const Color(0xFF94A3B8); // Grey
        label = 'FREE';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      title: 'User Management Engine',
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (val) {
                      setState(() {
                        _searchQuery = val;
                        _applyFiltersAndSort();
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Filter by UUID or Email...',
                      prefixIcon: Icon(Icons.filter_alt_rounded),
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: _fetchUsers,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reload DB'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                )
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredUsers.isEmpty
                        ? const Center(child: Text('No records match your filter.'))
                        : Scrollbar(
                            controller: _horizontalScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _horizontalScrollController,
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                controller: _verticalScrollController,
                                child: DataTable(
                                  sortColumnIndex: _sortColumnIndex,
                                  sortAscending: _isSortAscending,
                                  dataRowMinHeight: 32,
                                  dataRowMaxHeight: 48,
                                  headingRowHeight: 48,
                                  headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                                  border: TableBorder.all(color: Colors.grey.shade200, width: 1),
                                   columns: [
                                    DataColumn(label: const Text('Actions')),
                                    DataColumn(label: const Text('UUID (Short)'), onSort: _onSort),
                                    DataColumn(label: const Text('Email'), onSort: _onSort),
                                    DataColumn(label: const Text('Status'), onSort: _onSort),
                                    DataColumn(label: const Text('Plan'), onSort: _onSort),
                                    DataColumn(label: const Text('Cycle'), onSort: _onSort),
                                    DataColumn(label: const Text('LTV'), numeric: true, onSort: _onSort),
                                    DataColumn(label: const Tooltip(message: 'Lifetime AI writing assist invocations', child: Text('AI Credits')), numeric: true, onSort: _onSort),
                                    DataColumn(label: const Tooltip(message: 'Estimated cost based on actual token usage', child: Text('AI Cost')), numeric: true, onSort: _onSort),
                                    DataColumn(label: const Text('Notes'), numeric: true, onSort: _onSort),
                                    DataColumn(label: const Text('Storage'), numeric: true, onSort: _onSort),
                                    DataColumn(label: const Text('Last Active'), onSort: _onSort),
                                    DataColumn(label: const Text('Created At'), onSort: _onSort),
                                  ],
                                rows: _filteredUsers.map((user) {
                                  final shortId = (user['id'] ?? '').toString().split('-').first;
                                  return DataRow(cells: [
                                    DataCell(
                                      PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert_rounded, size: 20),
                                        onSelected: (val) {
                                          if (val == 'premium_free') _grantPremiumFree(user['id']);
                                        },
                                        itemBuilder: (ctx) => [
                                          const PopupMenuItem(value: 'premium_free', child: Text('Grant Premium Free')),
                                        ],
                                      )
                                    ),
                                    DataCell(Text(shortId, style: const TextStyle(fontFamily: 'monospace', color: Colors.grey))),
                                    DataCell(SelectableText(user['email'] ?? 'Unknown')),
                                    DataCell(Text(user['account_status'] ?? 'N/A')),
                                    DataCell(_planBadge(user['account_type'])),
                                    DataCell(Text(user['billing_cycle'] ?? 'N/A')),
                                    DataCell(Text(_formatCurrency(user['lifetime_value']))),
                                    DataCell(Text('${user['ai_credits_used'] ?? 0}')),
                                    DataCell(Text(_formatCurrency(_calcAiCost(user)))),
                                    DataCell(Text('${user['cached_notes_count'] ?? 0}')),
                                    DataCell(Text(_formatBytes(user['cached_storage_bytes']))),
                                    DataCell(Text(_formatDate(user['last_active_at']))),
                                    DataCell(Text(_formatDate(user['created_at']))),
                                  ]);
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
