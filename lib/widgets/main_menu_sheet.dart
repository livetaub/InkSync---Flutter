import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';

import '../screens/help/help_screen.dart';
import '../screens/trash/trash_screen.dart';
import '../screens/settings/settings_screen.dart';
import '../screens/invites/pending_invites_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import '../utils/ui_helper.dart';

/// Floating menu sheet with navigation and actions
class MainMenuSheet extends StatefulWidget {
  final bool isFloating;
  final Future<void> Function()? onDataChanged;

  const MainMenuSheet({
    super.key, 
    this.isFloating = false,
    this.onDataChanged,
  });

  @override
  State<MainMenuSheet> createState() => _MainMenuSheetState();
}

class _MainMenuSheetState extends State<MainMenuSheet> {
  bool _isSyncing = false;
  DateTime? _lastSyncAt;

  String _formatSyncTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = Provider.of<AuthService>(context, listen: false);

    return ClipRRect(
      borderRadius: widget.isFloating
          ? BorderRadius.circular(24)
          : const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                : Colors.white.withValues(alpha: 0.98),
            borderRadius: widget.isFloating
                ? BorderRadius.circular(24)
                : const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Native drag handle and close button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Drag handle
                        if (!widget.isFloating)
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : Colors.black12,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        // Close button
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              color: isDark ? Colors.white54 : Colors.black54,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            iconSize: 22,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMenuItem(
                    context,
                    icon: Icons.workspace_premium_rounded,
                    iconColor: Colors.amber,
                    title: 'Manage Subscription',
                    onTap: () {
                      Navigator.pop(context);
                      final isWide = MediaQuery.of(context).size.width > 900;
                      if (isWide) {
                        showLargeDialog(
                          context: context,
                          child: const SubscriptionScreen(isDialog: true),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SubscriptionScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.mail_outline_rounded,
                    title: 'Pending Invites',
                    onTap: () async {
                      Navigator.pop(context);
                      final isWide = MediaQuery.of(context).size.width > 900;
                      if (isWide) {
                        await showLargeDialog(
                          context: context,
                          child: const PendingInvitesScreen(isDialog: true),
                        );
                      } else {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PendingInvitesScreen(),
                          ),
                        );
                      }
                      if (widget.onDataChanged != null) {
                        widget.onDataChanged!();
                      }
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.sync_rounded,
                    title: _isSyncing ? 'Syncing...' : 'Sync Now',
                    trailing: _lastSyncAt != null && !_isSyncing
                        ? Text(
                            'Updated ${_formatSyncTime(_lastSyncAt!)}',
                            style: TextStyle(
                              color: isDark ? Colors.white54 : Colors.black54,
                              fontSize: 11,
                            ),
                          )
                        : (_isSyncing
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : null),
                    onTap: () async {
                      if (_isSyncing) return;
                      setState(() => _isSyncing = true);
                      
                      try {
                        if (widget.onDataChanged != null) {
                          await widget.onDataChanged!();
                        } else {
                          await Future.delayed(const Duration(milliseconds: 500));
                        }
                        if (mounted) {
                          setState(() {
                            _isSyncing = false;
                            _lastSyncAt = DateTime.now();
                          });
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSyncing = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sync failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_outline_rounded,
                    title: 'Trash',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TrashScreen()),
                      );
                    },
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      final isWide = MediaQuery.of(context).size.width > 900;
                      if (isWide) {
                        showLargeDialog(
                          context: context,
                          child: const SettingsScreen(isDialog: true),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  _buildMenuItem(
                    context,
                    icon: Icons.share_outlined,
                    title: 'Share the App',
                    onTap: () {
                      Navigator.pop(context);
                      Share.share(
                        'Check out InkSync - A beautiful note-taking app!\nhttps://inksyncnote.com',
                        subject: 'InkSync - Note Taking App',
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.feedback_outlined,
                    title: 'Help & Feedback',
                    onTap: () {
                      Navigator.pop(context);
                      final isWide = MediaQuery.of(context).size.width > 900;
                      if (isWide) {
                        showLargeDialog(
                          context: context,
                          child: const HelpScreen(isDialog: true),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const HelpScreen()),
                        );
                      }
                    },
                  ),
                  const Divider(height: 16, indent: 16, endIndent: 16),
                  if (authService.isLoggedIn)
                    _buildMenuItem(
                      context,
                      customIcon: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.redAccent.withValues(alpha: 0.15),
                        child: Text(
                          (authService.currentUserEmail ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.redAccent,
                          ),
                        ),
                      ),
                      title: 'Sign Out (${authService.currentUserEmail ?? "User"})',
                      titleColor: Colors.redAccent,
                      onTap: () async {
                        Navigator.pop(context);
                        await authService.signOut();
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/login', (r) => false);
                        }
                      },
                    )
                  else
                    _buildMenuItem(
                      context,
                      icon: Icons.login_rounded,
                      title: 'Log In or Sign Up',
                      iconColor: AppTheme.primaryColor,
                      onTap: () async {
                        Navigator.pop(context);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.remove('has_seen_onboarding');
                        await prefs.remove('is_guest_mode');
                        if (context.mounted) {
                          Navigator.pushNamedAndRemoveUntil(context, '/app', (r) => false);
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    IconData? icon,
    Widget? customIcon,
    required String title,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color:
                iconColor?.withValues(alpha: 0.1) ??
                (isDark
                    ? Colors.white10
                    : Colors.black.withValues(alpha: 0.03)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: customIcon ?? Icon(
            icon,
            color:
                iconColor ?? (isDark ? Colors.white70 : AppTheme.textSecondary),
            size: 18,
          ),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: titleColor ?? (isDark ? Colors.white : AppTheme.textPrimary),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
          ),
        ),
        trailing: trailing,
        dense: true,
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
