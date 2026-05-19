import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Banner widget to display pending collaboration invites
class InviteBanner extends StatelessWidget {
  final List<Map<String, dynamic>> invites;
  final Function(String inviteId) onAccept;
  final Function(String inviteId) onReject;
  final Function(String inviteId) onDismiss;

  const InviteBanner({
    super.key,
    required this.invites,
    required this.onAccept,
    required this.onReject,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (invites.isEmpty) return const SizedBox.shrink();

    return Column(
      children: invites
          .map((invite) => _buildInviteCard(context, invite))
          .toList(),
    );
  }

  Widget _buildInviteCard(BuildContext context, Map<String, dynamic> invite) {
    final fromEmail = invite['from_email'] ?? 'Someone';
    final noteTitle = invite['note_title'] ?? 'a note';
    final canEdit = invite['can_edit'] ?? true;
    final inviteId = invite['id'];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primaryColor.withValues(alpha: 0.1),
            AppTheme.primaryColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline, color: AppTheme.primaryColor, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Collaboration Invite',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                    fontSize: 13,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: canEdit
                      ? Colors.blue.withValues(alpha: 0.1)
                      : Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  canEdit ? 'Editor' : 'View only',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: canEdit ? Colors.blue : Colors.grey,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onDismiss(inviteId),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$fromEmail invited you to collaborate on "$noteTitle"',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => onReject(inviteId),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red.shade400,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: const Text('Decline'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => onAccept(inviteId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
