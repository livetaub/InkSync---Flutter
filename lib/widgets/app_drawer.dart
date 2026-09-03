import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/local_database_service.dart';
import '../screens/auth/login_screen.dart';
import 'auth_dialogs.dart';

import '../screens/trash/trash_screen.dart';
import '../screens/help/help_screen.dart';
import '../screens/subscription/subscription_screen.dart';
import 'package:helploop_sdk/helploop_sdk.dart';

/// App Drawer with profile section and menu items
class AppDrawer extends StatelessWidget {
  final VoidCallback? onSettingsTap;
  final VoidCallback? onSyncTap;

  const AppDrawer({super.key, this.onSettingsTap, this.onSyncTap});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Profile Header
            _buildProfileHeader(context, authService),

            const Divider(height: 1),

            // Menu Items
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.workspace_premium,
                    iconColor: Colors.amber,
                    title: 'Subscription',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.sync,
                    title: 'Sync',
                    subtitle: 'Tap to sync now',
                    onTap: () {
                      Navigator.pop(context);
                      onSyncTap?.call();
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_outline,
                    title: 'Trash',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TrashScreen()),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.settings_outlined,
                    title: 'Settings',
                    onTap: () {
                      Navigator.pop(context);
                      onSettingsTap?.call();
                    },
                  ),
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
                    icon: Icons.help_outline,
                    title: 'Help',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                  StreamBuilder<int>(
                    stream: HelpLoop.unreadCountStream,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return _buildMenuItem(
                        context,
                        icon: Icons.sms_outlined,
                        title: 'Contact Support',
                        trailing: count > 0 
                          ? Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                count > 99 ? '99+' : count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                          : null,
                        onTap: () {
                          Navigator.pop(context);
                          HelpLoop.open(context);
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sign Out at bottom
            const Divider(height: 1),
            if (authService.isLoggedIn)
              _buildMenuItem(
                context,
                icon: Icons.logout,
                iconColor: Colors.red,
                title: 'Sign Out',
                titleColor: Colors.red,
                onTap: () async {
                  Navigator.pop(context);
                  if (!kIsWeb) {
                    final confirmed = await showLogoutConfirmDialog(context);
                    if (!confirmed) return;
                    await LocalDatabaseService.instance.wipeAllData();
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('has_seen_onboarding');
                    await prefs.remove('is_guest_mode');
                  }
                  await authService.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/app', (r) => false);
                  }
                },
              )
            else
              _buildMenuItem(
                context,
                icon: Icons.login,
                iconColor: AppTheme.primaryColor,
                title: 'Log In / Register',
                titleColor: AppTheme.primaryColor,
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthService authService) {
    final email = authService.isLoggedIn ? (authService.currentUserEmail ?? 'User') : 'Guest User';
    final name = authService.isLoggedIn ? email.split('@').first : 'Local storage only';

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
            child: const Icon(
              Icons.person_outline,
              size: 32,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _capitalizeFirstLetter(name),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? iconColor,
    Color? titleColor,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: TextStyle(
                color: AppTheme.textSecondary.withValues(alpha: 0.8),
                fontSize: 12,
              ),
            )
          : null,
      trailing: trailing,
      onTap: onTap,
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

}
