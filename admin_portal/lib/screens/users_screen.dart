import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    _loadSavedSortSettings().then((_) => _fetchUsers());
  }

  Future<void> _loadSavedSortSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedColIndex = prefs.getInt('admin_users_sort_column_index');
      final savedAscending = prefs.getBool('admin_users_sort_ascending');
      
      if (mounted && savedColIndex != null && savedAscending != null) {
        setState(() {
          _sortColumnIndex = savedColIndex;
          _sortDataIndex = savedColIndex - 1;
          _isSortAscending = savedAscending;
        });
      }
    } catch (e) {
      debugPrint('[UsersScreen] Error loading sort settings: $e');
    }
  }

  Future<void> _saveSortSettings(int columnIndex, bool ascending) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('admin_users_sort_column_index', columnIndex);
      await prefs.setBool('admin_users_sort_ascending', ascending);
    } catch (e) {
      debugPrint('[UsersScreen] Error saving sort settings: $e');
    }
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
    _saveSortSettings(columnIndex, ascending);
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

  String _getSortLabel() {
    switch (_sortColumnIndex) {
      case 12:
        return _isSortAscending ? 'Created At (Oldest)' : 'Created At (Newest)';
      case 2:
        return _isSortAscending ? 'Email (A-Z)' : 'Email (Z-A)';
      case 9:
        return _isSortAscending ? 'Notes (Low-High)' : 'Notes (High-Low)';
      case 6:
        return _isSortAscending ? 'LTV (Low-High)' : 'LTV (High-Low)';
      case 11:
        return _isSortAscending ? 'Last Active (Oldest)' : 'Last Active (Recent)';
      default:
        return 'Sort Options';
    }
  }

  Widget _buildSortButton() {
    return PopupMenuButton<Map<String, dynamic>>(
      offset: const Offset(0, 40),
      onSelected: (option) {
        _onSort(option['col'] as int, option['asc'] as bool);
      },
      itemBuilder: (ctx) => [
        _buildSortMenuItem('Created At (Newest)', 12, false),
        _buildSortMenuItem('Created At (Oldest)', 12, true),
        _buildSortMenuItem('Email (A-Z)', 2, true),
        _buildSortMenuItem('Email (Z-A)', 2, false),
        _buildSortMenuItem('Notes (High-Low)', 9, false),
        _buildSortMenuItem('Notes (Low-High)', 9, true),
        _buildSortMenuItem('LTV (High-Low)', 6, false),
        _buildSortMenuItem('LTV (Low-High)', 6, true),
        _buildSortMenuItem('Last Active (Recent)', 11, false),
        _buildSortMenuItem('Last Active (Oldest)', 11, true),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: Colors.black87),
            const SizedBox(width: 8),
            Text(
              _getSortLabel(),
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.black87),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down_rounded, size: 18, color: Colors.black54),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<Map<String, dynamic>> _buildSortMenuItem(String label, int col, bool asc) {
    final isSelected = _sortColumnIndex == col && _isSortAscending == asc;
    return PopupMenuItem<Map<String, dynamic>>(
      value: {'col': col, 'asc': asc},
      child: Row(
        children: [
          Icon(
            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            size: 16,
            color: isSelected ? const Color(0xFF3B82F6) : Colors.grey,
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400)),
        ],
      ),
    );
  }

  Widget _buildMobileUserCard(Map<String, dynamic> user) {
    final email = user['email'] ?? 'Unknown';
    final notesCount = user['cached_notes_count'] ?? 0;
    final createdAt = _formatDate(user['created_at']);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          title: Text(
            email,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.black87),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _planBadge(user['account_type']),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.notes_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text('$notesCount notes', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                Text(
                  'Created: $createdAt',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildDetailRow('UUID (Full)', user['id'] ?? 'N/A'),
                  _buildDetailRow('Account Status', user['account_status'] ?? 'N/A'),
                  _buildDetailRow('Billing Cycle', user['billing_cycle'] ?? 'N/A'),
                  _buildDetailRow('LTV', _formatCurrency(user['lifetime_value'])),
                  _buildDetailRow('AI Credits', '${user['ai_credits_used'] ?? 0}'),
                  _buildDetailRow('AI Cost', _formatCurrency(_calcAiCost(user))),
                  _buildDetailRow('Storage', _formatBytes(user['cached_storage_bytes'])),
                  _buildDetailRow('Last Active', _formatDate(user['last_active_at'])),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _grantPremiumFree(user['id']),
                        icon: const Icon(Icons.card_membership_rounded, size: 16),
                        label: const Text('Grant Premium Free', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B5CF6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 35,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF64748B)),
            ),
          ),
          Expanded(
            flex: 65,
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 750;
    final padding = isMobile ? 12.0 : 24.0;

    return AdminScaffold(
      title: 'User Management Engine',
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
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
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildSortButton()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _fetchUsers,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reload DB'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Row(
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
                  _buildSortButton(),
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
                        : isMobile
                            ? ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _filteredUsers.length,
                                itemBuilder: (ctx, index) {
                                  final user = _filteredUsers[index];
                                  return _buildMobileUserCard(user);
                                },
                              )
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
                                      columns: const [
                                        DataColumn(label: Text('Actions')),
                                        DataColumn(label: Text('UUID (Short)')),
                                        DataColumn(label: Text('Email')),
                                        DataColumn(label: Text('Status')),
                                        DataColumn(label: Text('Plan')),
                                        DataColumn(label: Text('Cycle')),
                                        DataColumn(label: Text('LTV'), numeric: true),
                                        DataColumn(label: Tooltip(message: 'Lifetime AI writing assist invocations', child: Text('AI Credits')), numeric: true),
                                        DataColumn(label: Tooltip(message: 'Estimated cost based on actual token usage', child: Text('AI Cost')), numeric: true),
                                        DataColumn(label: Text('Notes'), numeric: true),
                                        DataColumn(label: Text('Storage'), numeric: true),
                                        DataColumn(label: Text('Last Active')),
                                        DataColumn(label: Text('Created At')),
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
