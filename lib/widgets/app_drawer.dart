import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/settings_service.dart';
import '../screens/trash/trash_screen.dart';
import '../screens/tutorial/tutorial_screen.dart';
import '../screens/help/help_screen.dart';

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
                    title: 'Upgrade to Premium',
                    onTap: () {
                      Navigator.pop(context);
                      _showUpgradeDialog(context);
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
                  const Divider(),
                  _buildMenuItem(
                    context,
                    icon: Icons.help_outline,
                    title: 'Tutorial',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorialScreen(),
                        ),
                      );
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
                    icon: Icons.feedback_outlined,
                    title: 'Help & Feedback',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HelpScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Sign Out at bottom
            const Divider(height: 1),
            _buildMenuItem(
              context,
              icon: Icons.logout,
              iconColor: Colors.red,
              title: 'Sign Out',
              titleColor: Colors.red,
              onTap: () async {
                Navigator.pop(context);
                await authService.signOut();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, AuthService authService) {
    final email = authService.currentUserEmail ?? 'User';
    final name = email.split('@').first;

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
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? AppTheme.textSecondary, size: 24),
      title: Text(
        title,
        style: TextStyle(
          color: titleColor ?? AppTheme.textPrimary,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
            )
          : null,
      onTap: onTap,
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  void _showUpgradeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.star, color: Colors.amber),
            SizedBox(width: 8),
            Text('Upgrade to Premium'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Unlock these features:'),
            const SizedBox(height: 12),
            _buildFeatureRow(Icons.auto_fix_high, 'AI Writing Tools'),
            _buildFeatureRow(Icons.people_outline, 'Collaboration'),
            _buildFeatureRow(Icons.palette, 'Advanced Customization'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Maybe later'),
          ),
          ElevatedButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              final settingsService = SettingsService(authService);
              await settingsService.upgradeToPremium();
              navigator.pop();
            },
            child: const Text('Upgrade'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }
}
