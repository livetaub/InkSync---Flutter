import 'dart:ui';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import 'package:provider/provider.dart';


/// Collapsed mobile sidebar showing only icons
/// Provides navigation similar to desktop but optimized for mobile screens
class MobileSidebar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onIndexChanged;
  final VoidCallback onCreateNote;
  final VoidCallback onMenuOpen;
  final VoidCallback onSync;
  final VoidCallback onSearch;
  final bool isSyncing;
  final DateTime? lastSyncAt;

  const MobileSidebar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.onCreateNote,
    required this.onMenuOpen,
    required this.onSync,
    required this.onSearch,
    this.isSyncing = false,
    this.lastSyncAt,
  });

  @override
  State<MobileSidebar> createState() => _MobileSidebarState();
}

class _MobileSidebarState extends State<MobileSidebar> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 60, // Slightly narrower
      height: double.infinity,
      child: Stack(
        children: [
          // Layer 1: Background image (same as desktop)
          Positioned.fill(
            child: Image.asset(
              'assets/images/sidebar_bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Layer 2: Very subtle blur
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.transparent),
            ),
          ),

          // Layer 3: Semi-transparent overlay with padding and rounded edges
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1117).withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.10),
                    width: 1,
                  ),
                ),
              ),
            ),
          ),

          // Layer 4: Content
          Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 10),

                // "+ New" Button (compact) - at top
                _buildNewButton(),

                const SizedBox(height: 8),

                // Search Button
                _buildSearchButton(),

                const SizedBox(height: 8),

                // Divider
                Container(
                  width: 32,
                  height: 1,
                  color: Colors.white.withValues(alpha: 0.15),
                ),

                const SizedBox(height: 8),

                // Navigation Items - wrapped in Expanded to take remaining space
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildNavIcon(0, Icons.description_outlined, 'Notes'),
                        _buildNavIcon(1, Icons.checklist_rounded, 'Checklists'),
                        _buildNavIcon(
                          2,
                          Icons.calendar_today_outlined,
                          'Calendar',
                        ),
                        // More button - together with nav icons
                        _buildMoreButton(),
                      ],
                    ),
                  ),
                ),

                // User Avatar (compact) at bottom
                _buildUserAvatar(),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNewButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: 'Create New',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onCreateNote,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10D98C), Color(0xFF08C77D)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10D98C).withValues(alpha: 0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchButton() {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: 'Search',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onSearch,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 0.5,
                ),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(int index, IconData icon, String label) {
    final isSelected = widget.currentIndex == index;
    const selectedColor = AppTheme.selectionBlue; // Blue color for selection

    return Tooltip(
      message: label,
      child: Padding(
        padding: const EdgeInsets.only(left: 6, top: 1, bottom: 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => widget.onIndexChanged(index),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Selection indicator bar (left side)
                if (isSelected)
                  Positioned(
                    left: 0,
                    child: Container(
                      width: 3,
                      height: 22,
                      decoration: BoxDecoration(
                        color: selectedColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                // Icon container
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? selectedColor : Colors.white54,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMoreButton() {
    return Tooltip(
      message: 'Menu',
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: widget.onMenuOpen,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.menu_rounded,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }





  Widget _buildUserAvatar() {
    final authService = Provider.of<AuthService>(context, listen: false);
    return StreamBuilder<UserSettings>(
      stream: SettingsService(authService).getSettingsStream(),
      builder: (context, settingsSnapshot) {
        final isPremium = settingsSnapshot.data?.isPremium ?? false;
        final userEmail = authService.currentUserEmail ?? 'User';
        final displayName = authService.currentUserDisplayName;
        final userName = displayName ?? userEmail.split('@').first;
        final userPhoto = authService.currentUserPhotoUrl;

        return Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Tooltip(
            message: userName,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isPremium
                      ? Colors.amber.withValues(alpha: 0.4)
                      : Colors.white.withValues(alpha: 0.08),
                  width: isPremium ? 2 : 0.5,
                ),
                gradient: userPhoto == null
                    ? const LinearGradient(
                        colors: [Color(0xFF10D98C), Color(0xFF08C77D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                image: userPhoto != null
                    ? DecorationImage(
                        image: NetworkImage(userPhoto),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: userPhoto == null
                  ? Center(
                      child: Text(
                        userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
