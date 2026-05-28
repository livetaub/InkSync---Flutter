import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/notes_service.dart';

/// Screen to view and manage pending collaboration invites
class PendingInvitesScreen extends StatefulWidget {
  final bool isDialog;

  const PendingInvitesScreen({super.key, this.isDialog = false});

  @override
  State<PendingInvitesScreen> createState() => _PendingInvitesScreenState();
}

class _PendingInvitesScreenState extends State<PendingInvitesScreen> {
  List<Map<String, dynamic>> _pendingInvites = [];
  List<Map<String, dynamic>> _declinedInvites = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  Future<void> _loadInvites() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notesService = NotesService(authService);
    final pending = await notesService.getPendingInvites();
    final declined = await notesService.getRejectedInvites();
    
    if (mounted) {
      setState(() {
        _pendingInvites = pending;
        _declinedInvites = declined;
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptInvite(String inviteId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notesService = NotesService(authService);
    await notesService.acceptInvite(inviteId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Invite accepted! Note added to your collection.'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
      _loadInvites();
    }
  }

  Future<void> _rejectInvite(String inviteId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final notesService = NotesService(authService);
    await notesService.rejectInvite(inviteId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite declined')),
      );
      _loadInvites();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = DefaultTabController(
      length: 2,
      child: Column(
        children: [
          if (widget.isDialog)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      'Invites',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
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
          TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Declined'),
            ],
          ),
          if (widget.isDialog) const Divider(height: 1),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: [
                      _buildList(_pendingInvites, isDark, isDeclined: false),
                      _buildList(_declinedInvites, isDark, isDeclined: true),
                    ],
                  ),
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return content;
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Invites',
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          bottom: TabBar(
            labelColor: AppTheme.primaryColor,
            unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
            indicatorColor: AppTheme.primaryColor,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Declined'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildList(_pendingInvites, isDark, isDeclined: false),
                  _buildList(_declinedInvites, isDark, isDeclined: true),
                ],
              ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> invites, bool isDark, {required bool isDeclined}) {
    if (invites.isEmpty) {
      return _buildEmptyState(isDark, isDeclined: isDeclined);
    }
    
    return RefreshIndicator(
      onRefresh: _loadInvites,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: invites.length,
        itemBuilder: (context, index) =>
            _buildInviteCard(context, invites[index], isDark, isDeclined: isDeclined),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, {required bool isDeclined}) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDeclined ? Icons.block_flipped : Icons.mail_outline_rounded,
              size: 48,
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isDeclined ? 'No declined invites' : 'No pending invites',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isDeclined 
                ? 'Invites you decline will appear here.'
                : 'When someone invites you to collaborate\non a note, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard(
    BuildContext context,
    Map<String, dynamic> invite,
    bool isDark, {
    required bool isDeclined,
  }) {
    final fromEmail = invite['from_email'] ?? 'Someone';
    final noteTitle = invite['note_title'] ?? 'Untitled Note';
    final canEdit = invite['can_edit'] ?? true;
    final inviteId = invite['id'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.mail_outline_rounded,
                    color: AppTheme.primaryColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fromEmail,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Invited you to collaborate',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black45,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: canEdit
                        ? Colors.blue.withValues(alpha: 0.1)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    canEdit ? 'Editor' : 'View only',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: canEdit ? Colors.blue : Colors.grey,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Note title card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.04)
                    : const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : const Color(0xFFBBF7D0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      noteTitle,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                if (!isDeclined)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _rejectInvite(inviteId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red.shade400,
                        side: BorderSide(color: Colors.red.shade200),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Decline',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                if (!isDeclined) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () => _acceptInvite(inviteId),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text(
                      'Accept Invite',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
