import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Choices for guest note import dialog
enum GuestImportChoice { importNotes, skip }

/// Show dialog when guest user signs in — offers to import local notes.
/// Returns null if dismissed.
Future<GuestImportChoice?> showGuestImportDialog(
  BuildContext context,
  int noteCount,
) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showDialog<GuestImportChoice>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D21) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row with icon and info button
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.cloud_upload_rounded,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: GestureDetector(
                      onTap: () => _showStorageInfoSheet(ctx),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.info_outline_rounded,
                          size: 18,
                          color: isDark ? Colors.white54 : AppTheme.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Import Your Notes',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              'You have $noteCount ${noteCount == 1 ? 'note' : 'notes'} saved on this device. '
              'Would you like to import ${noteCount == 1 ? 'it' : 'them'} to your account?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Once imported, your notes will be synced across all your devices.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white38 : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 28),

            // Import button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(ctx, GuestImportChoice.importNotes),
                icon: const Icon(Icons.cloud_upload_rounded, size: 18),
                label: const Text(
                  'Import & Continue',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Skip button
            TextButton(
              onPressed: () => Navigator.pop(ctx, GuestImportChoice.skip),
              child: Text(
                'Skip — notes won\'t sync',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Show logout confirmation dialog.
/// Returns true if user confirms, false/null if cancelled.
Future<bool> showLogoutConfirmDialog(BuildContext context) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1D21) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.logout_rounded,
                color: Colors.redAccent,
                size: 28,
              ),
            ),
            const SizedBox(height: 20),

            // Title
            Text(
              'Sign Out?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            // Body
            Text(
              'Your notes are safely stored in the cloud and won\'t be affected.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.55,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The local copy on this device will be cleared. '
              'When you sign back in, your notes will resync automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.white38 : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 28),

            // Sign Out button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Sign Out',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Cancel button
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                'Cancel',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white54 : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  return result ?? false;
}

/// Show bottom sheet explaining how InkSync stores data
void _showStorageInfoSheet(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Container(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 36),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1D21) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Text(
            'How InkSync Stores Your Data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

          // Local storage
          _buildInfoRow(
            isDark,
            Icons.phone_android_rounded,
            AppTheme.primaryColor,
            'On Your Device',
            'A local copy of your notes is stored for fast, offline access. '
            'This data stays on your device only.',
          ),
          const SizedBox(height: 20),

          // Cloud storage
          _buildInfoRow(
            isDark,
            Icons.cloud_rounded,
            const Color(0xFF4A9DFF),
            'In the Cloud',
            'When signed in, your notes are securely backed up and synced '
            'across all your devices in real time.',
          ),
          const SizedBox(height: 20),

          // Guest notes
          _buildInfoRow(
            isDark,
            Icons.person_outline_rounded,
            Colors.amber,
            'Guest Notes',
            'Notes created as a guest are stored only on this device. '
            'Import them to your account to back them up and sync them.',
          ),
          const SizedBox(height: 28),

          // Got it button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Got It',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildInfoRow(
  bool isDark,
  IconData icon,
  Color iconColor,
  String title,
  String description,
) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.white54 : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
