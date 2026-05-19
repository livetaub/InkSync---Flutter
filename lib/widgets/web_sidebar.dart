import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../screens/tutorial/tutorial_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/invites/pending_invites_screen.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';


final authService = AuthService();

class WebSidebar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;
  final VoidCallback onMenuOpen;
  final VoidCallback onCreateNote;
  final VoidCallback onCreateChecklist;
  final VoidCallback onSync;
  final VoidCallback onTrashOpen;
  final VoidCallback onSearch;
  final bool isSyncing;
  final DateTime? lastSyncAt;

  const WebSidebar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onMenuOpen,
    required this.onCreateNote,
    required this.onCreateChecklist,
    required this.onSync,
    required this.onTrashOpen,
    required this.onSearch,
    this.isSyncing = false,
    this.lastSyncAt,
  });

  @override
  State<WebSidebar> createState() => _WebSidebarState();
}

class _WebSidebarState extends State<WebSidebar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isMenuExpanded = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 240,
      height: double.infinity,
      child: Stack(
        children: [
          // Layer 1: Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/sidebar_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Layer 2: Very subtle blur (optional)
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Layer 3: Semi-transparent overlay with padding and rounded edges
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117).withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // Layer 4: Content (with padding to match overlay)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                const SizedBox(height: 16),

                // "+ New" Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showCreateDialog(context),
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF10D98C), Color(0xFF08C77D)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF10D98C,
                              ).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'New',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Search Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: widget.onSearch,
                      child: Container(
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.1),
                            width: 0.5,
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_rounded,
                              color: Colors.white70,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Search',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Scrollable Navigation Area
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Navigation Items
                        _buildNavItem(0, Icons.description_outlined, 'Notes'),
                        _buildNavItem(1, Icons.checklist_rounded, 'Checklists'),
                        _buildNavItem(
                          2,
                          Icons.calendar_today_outlined,
                          'Calendar',
                        ),
                        _buildNavItem(
                          -1,
                          Icons.menu_rounded,
                          'Menu',
                          isMenu: true,
                        ),
                        if (_isMenuExpanded) _buildExpandedMenu(),
                      ],
                    ),
                  ),
                ),


              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildExpandedMenu() {
    final userEmail = authService.currentUserEmail ?? 'User';
    return Column(
      children: [
        const SizedBox(height: 8),
        _buildMenuSubItem(
          Icons.workspace_premium_rounded,
          'Upgrade to Premium',
          Colors.amber,
          () => Navigator.pushNamed(context, '/pricing'),
        ),
        _buildMenuSubItem(
          Icons.mail_outline_rounded,
          'Pending Invites',
          null,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PendingInvitesScreen())),
        ),
        _buildMenuSubItem(
          Icons.sync_rounded,
          widget.isSyncing ? 'Syncing...' : 'Sync Now',
          null,
          () {
            if (!widget.isSyncing) widget.onSync();
          },
          trailing: widget.lastSyncAt != null && !widget.isSyncing
              ? Text(
                  'Updated ${_formatSyncTime(widget.lastSyncAt!)}',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                )
              : (widget.isSyncing 
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54)) 
                  : null),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(color: Colors.white12, height: 1),
        ),
        _buildMenuSubItem(
          Icons.delete_outline_rounded,
          'Trash',
          null,
          widget.onTrashOpen,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(color: Colors.white12, height: 1),
        ),
        _buildMenuSubItem(
          Icons.settings_outlined,
          'Settings',
          null,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
        ),
        _buildMenuSubItem(
          Icons.help_outline_rounded,
          'Tutorial',
          null,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TutorialScreen())),
        ),
        _buildMenuSubItem(
          Icons.share_outlined,
          'Share the App',
          null,
          () => Share.share(
            'Check out InkSync - A beautiful note-taking app!\nhttps://inksyncnote.com',
            subject: 'InkSync - Note Taking App',
          ),
        ),
        _buildMenuSubItem(
          Icons.feedback_outlined,
          'Help & Feedback',
          null,
          () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen())),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 28, vertical: 8),
          child: Divider(color: Colors.white12, height: 1),
        ),
        _buildMenuSubItem(
          Icons.logout_rounded,
          'Sign Out ($userEmail)',
          Colors.redAccent,
          () async => await authService.signOut(),
        ),
      ],
    );
  }

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildMenuSubItem(
    IconData icon,
    String label,
    Color? color,
    VoidCallback onTap, {
    Widget? trailing,
  }) {
    final iconColor = color ?? Colors.white54;
    return Padding(
      padding: const EdgeInsets.only(left: 28, right: 8, top: 0, bottom: 0),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color ?? Colors.white54,
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: 280,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1D21),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create New',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),

              // Add Note option
              _buildDialogOption(
                context,
                icon: Icons.description_outlined,
                label: 'Note',
                subtitle: 'Write text, add images',
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateNote();
                },
              ),

              const SizedBox(height: 12),

              // Add Checklist option
              _buildDialogOption(
                context,
                icon: Icons.checklist_rounded,
                label: 'Checklist',
                subtitle: 'Track tasks with checkboxes',
                onTap: () {
                  Navigator.pop(context);
                  widget.onCreateChecklist();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDialogOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10, width: 0.5),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primaryColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label, {
    bool isMenu = false,
  }) {
    // "More" should never be highlighted, only regular nav items
    final isSelected = !isMenu && widget.currentIndex == index;
    const selectedColor = Color(0xFF3B82F6); // Blue color for selection

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () {
            if (isMenu) {
              setState(() {
                _isMenuExpanded = !_isMenuExpanded;
              });
            } else {
              widget.onIndexChanged(index);
            }
          },
          child: Row(
            children: [
              // Blue vertical indicator OUTSIDE the highlight box
              Container(
                width: 3,
                height: 20,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  color: isSelected ? selectedColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Highlight box with icon and text
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        color: isSelected ? selectedColor : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        label,

                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                      // Spacer removed

                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
