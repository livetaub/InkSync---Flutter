import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../services/auth_service.dart';
import '../services/quick_note_service.dart';
import '../models/quick_note.dart';

class BrainDumpCard extends StatefulWidget {
  final VoidCallback? onTap;
  
  const BrainDumpCard({super.key, this.onTap});

  @override
  State<BrainDumpCard> createState() => _BrainDumpCardState();
}

class _BrainDumpCardState extends State<BrainDumpCard> {
  QuickNote? _latestMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestMessage();
  }

  Future<void> _loadLatestMessage() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final brainDumpService = QuickNoteService(authService);
      final messages = await brainDumpService.getMessages();
      
      if (mounted) {
        setState(() {
          if (messages.isNotEmpty) {
            _latestMessage = messages.last;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading brain dump preview: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getPreviewText() {
    if (_latestMessage == null) {
      return 'Tap to start capturing thoughts...';
    }
    
    switch (_latestMessage!.type) {
      case 'voice':
        return '🎤 Voice note';
      case 'image':
        return '📷 Photo';
      case 'pdf':
        return '📄 Document';
      case 'text':
      default:
        final content = _latestMessage!.content ?? '';
        if (content.length > 60) {
          return '${content.substring(0, 60)}...';
        }
        return content;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isDark 
              ? [const Color(0xFF1A2332), const Color(0xFF162028)]
              : [const Color(0xFFE8F5E9), const Color(0xFFE3F2FD)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left border accent
              Container(
                width: 3,
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sticky_note_2_rounded, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Quick Note',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          Icon(
                            Icons.push_pin,
                            size: 16,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const SizedBox(
                          height: 16, 
                          width: 16, 
                          child: CircularProgressIndicator(strokeWidth: 2)
                        )
                      else
                        Text(
                          _getPreviewText(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                          ),
                        ),
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
