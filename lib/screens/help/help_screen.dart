import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../utils/ui_helper.dart';
import '../tutorial/tutorial_screen.dart';

/// Help & Feedback screen with FAQs and contact options
class HelpScreen extends StatelessWidget {
  final bool isDialog;

  const HelpScreen({super.key, this.isDialog = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Column(
      children: [
        if (isDialog)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 8),
            child: Row(
              children: [
                const SizedBox(width: 48),
                Expanded(
                  child: Text(
                    'Help & Feedback',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
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
        if (isDialog) const Divider(height: 1),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Quick Actions
              _buildSection('Get Help', [
                _buildActionTile(
                  context,
                  icon: Icons.school_outlined,
                  title: 'App Tutorial',
                  subtitle: 'Learn how to use InkSync',
                  onTap: () {
                    if (isDialog) {
                      showLargeDialog(
                        context: context,
                        child: const TutorialScreen(isDialog: true),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TutorialScreen(),
                        ),
                      );
                    }
                  },
                  isDark: isDark,
                ),
                _buildActionTile(
                  context,
                  icon: Icons.email_outlined,
                  title: 'Contact Support',
                  subtitle: 'Send us an email',
                  onTap: () => _launchEmail(),
                  isDark: isDark,
                ),
                _buildActionTile(
                  context,
                  icon: Icons.bug_report_outlined,
                  title: 'Report a Bug',
                  subtitle: 'Help us improve',
                  onTap: () => _showFeedbackDialog(context, 'Bug Report'),
                  isDark: isDark,
                ),
                _buildActionTile(
                  context,
                  icon: Icons.lightbulb_outline,
                  title: 'Suggest a Feature',
                  subtitle: 'We love new ideas',
                  onTap: () => _showFeedbackDialog(context, 'Feature Request'),
                  isDark: isDark,
                ),
                _buildActionTile(
                  context,
                  icon: Icons.description_outlined,
                  title: 'Terms & Privacy Policy',
                  subtitle: 'Read our legal agreements',
                  onTap: () async {
                    final uri = Uri.parse('https://inksyncnote.com/terms');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  isDark: isDark,
                ),
              ], isDark: isDark),
              const SizedBox(height: 24),

          // FAQs
          _buildSection('Frequently Asked Questions', [
            _buildFaqTile(
              context,
              question: 'How do I create a note?',
              answer:
                  'Tap the + button on the home screen and select "Create Note" or "Create Checklist".',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'How do I lock a note?',
              answer:
                  'Open a note, tap the lock icon in the toolbar, and set a password. The note will require the password to view.',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'How do I share a note?',
              answer:
                  'Open a note, tap the menu (⋮) and select "Share". You can share via any app on your device.',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'How do I collaborate with others?',
              answer:
                  'Open a note, tap the people icon, and add collaborators by email. They will receive an invitation to view and edit the note.',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'How do I use AI writing tools?',
              answer:
                  'Open a text note, tap the magic wand icon (✨) in the toolbar. Select a tone to transform your text.',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'How do I recover deleted notes?',
              answer:
                  'Deleted notes go to Trash and are kept for 30 days. Open the drawer menu and tap "Trash" to restore them.',
              isDark: isDark,
            ),
            _buildFaqTile(
              context,
              question: 'Is my data synced across devices?',
              answer:
                  'Yes! Your notes sync automatically to the cloud when you\'re signed in. Access them from any device.',
              isDark: isDark,
            ),
          ], isDark: isDark),
          const SizedBox(height: 24),

          // App Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'About InkSync',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'InkSync is a beautiful note-taking app designed to help you capture, organize, and share your ideas effortlessly.',
                  style: TextStyle(
                    color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: isDark ? Colors.white38 : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        color: isDark ? Colors.white38 : Colors.grey.shade600,
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
  ],
);

    if (isDialog) {
      return content;
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Help & Feedback',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      body: content,
    );
  }

  Widget _buildSection(
    String title,
    List<Widget> children, {
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.05),
            ),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor),
      ),
      title: Text(
        title,
        style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : AppTheme.textMuted,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark ? Colors.white38 : Colors.grey,
      ),
      onTap: onTap,
    );
  }

  Widget _buildFaqTile(
    BuildContext context, {
    required String question,
    required String answer,
    required bool isDark,
  }) {
    return ExpansionTile(
      title: Text(
        question,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      iconColor: isDark ? Colors.white54 : Colors.grey,
      collapsedIconColor: isDark ? Colors.white54 : Colors.grey,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            answer,
            style: TextStyle(
              color: isDark ? Colors.white60 : AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchEmail() async {
    final uri = Uri.parse('mailto:support@inksync.app?subject=InkSync Support');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _showFeedbackDialog(BuildContext context, String type) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(type),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              type == 'Bug Report'
                  ? 'Please describe the issue you encountered:'
                  : 'Please describe your idea:',
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Enter your feedback...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Thank you for your feedback!')),
              );
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
