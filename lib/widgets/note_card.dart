import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../config/theme.dart';
import '../services/notes_service.dart';

/// Tactile, responsive NoteCard with left accent styling
class NoteCard extends StatefulWidget {
  final Note note;
  final String viewMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool isHighlighted;

  const NoteCard({
    super.key,
    required this.note,
    required this.viewMode,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.isHighlighted = false,
  });

  @override
  State<NoteCard> createState() => _NoteCardState();
}

class _NoteCardState extends State<NoteCard> with SingleTickerProviderStateMixin {
  bool _isHovered = false;
  bool _isPressed = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0.0, end: 12.0)
        .chain(CurveTween(curve: const ShakeCurve(count: 3.5)))
        .animate(_shakeController);
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(NoteCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isHighlighted && !oldWidget.isHighlighted) {
      _shakeController.forward(from: 0.0);
    }
  }

  String _getDisplayTitle() {
    if (widget.note.title.isNotEmpty) {
      return widget.note.title;
    }
    if (widget.note.isLocked) {
      return 'Locked Note';
    }

    // For Checklists: use first item as title
    if (widget.note.type == 'checklist' && widget.note.checklistItems.isNotEmpty) {
      final firstItemText = widget.note.checklistItems.first.text.trim();
      if (firstItemText.isNotEmpty) {
        return firstItemText.length > 50 
            ? '${firstItemText.substring(0, 50)}...' 
            : firstItemText;
      }
    }

    // For Text Notes: use first line of content
    final content = widget.note.content.trim();
    if (content.isNotEmpty) {
      final firstLine = content.split('\n').first;
      return firstLine.length > 50 
          ? '${firstLine.substring(0, 50)}...' 
          : firstLine;
    }
    return 'New Note';
  }

  String _getDisplayContent() {
    if (widget.note.isLocked) {
      return 'This note is locked';
    }

    if (widget.note.type == 'checklist') {
      final items = widget.note.checklistItems;
      if (items.isEmpty) return 'No items';
      final unchecked = items.where((i) => !i.checked).toList();
      if (unchecked.isEmpty) return '${items.length} items (all done)';
      return '${unchecked.first.text}${items.length > 1 ? ' +${items.length - 1} more' : ''}';
    }
    
    final content = widget.note.content.trim();
    if (content.isEmpty) return 'No content';
    
    // Remove the first line if it's used as title
    if (widget.note.title.isEmpty) {
      final lines = content.split('\n');
      if (lines.length > 1) {
        return lines.skip(1).join(' ').trim();
      }
    }
    
    return content;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Widget cardChild;
    if (widget.viewMode == 'list') {
      cardChild = _buildCondensedListItem(isDark);
    } else {
      cardChild = _buildCardView(isDark);
    }

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: cardChild,
    );
  }

  /// Condensed single-line row for list view: title left, time right
  Widget _buildCondensedListItem(bool isDark) {
    final timeString = widget.note.updatedDate != null
        ? _formatDateTime(widget.note.updatedDate!)
        : 'Just now';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark
                ? (_isHovered ? AppTheme.noteBodyColorsDark[widget.note.color] ?? AppTheme.surfaceDark : AppTheme.noteColorsDark[widget.note.color] ?? AppTheme.surfaceDark)
                : (_isHovered ? AppTheme.noteHeaderColors[widget.note.color] ?? Colors.white : AppTheme.noteColors[widget.note.color] ?? Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: (widget.isSelected || widget.isHighlighted)
                ? Border.all(
                    color: AppTheme.primaryColor,
                    width: 2.0,
                  )
                : Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.grey.withValues(alpha: 0.08),
                    width: 0.5,
                  ),
            boxShadow: (widget.isSelected || widget.isHighlighted)
                ? [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Pin indicator
              if (widget.note.isPinned)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 16,
                    color: AppTheme.primaryColor.withValues(alpha: 0.7),
                  ),
                ),

              // Lock indicator
              if (widget.note.isLocked)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.lock_rounded,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                ),

              // Title
              Expanded(
                child: Text(
                  _getDisplayTitle(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                    letterSpacing: -0.1,
                  ),
                ),
              ),

              // Collaboration indicator
              if (widget.note.collaborators.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Icon(
                    Icons.people_outline_rounded,
                    size: 16,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                  ),
                ),

              // Time modified
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                    color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Standard card view for details and grid modes
  Widget _buildCardView(bool isDark) {
    final backgroundColor = isDark
        ? (_isHovered ? AppTheme.noteBodyColorsDark[widget.note.color] ?? AppTheme.surfaceDark : AppTheme.noteColorsDark[widget.note.color] ?? AppTheme.surfaceDark)
        : (_isHovered ? AppTheme.noteHeaderColors[widget.note.color] ?? Colors.white : AppTheme.noteColors[widget.note.color] ?? Colors.white);

    final timeString = widget.note.updatedDate != null
        ? _formatDateTime(widget.note.updatedDate!)
        : 'Just now';

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) => setState(() => _isPressed = false),
        onTapCancel: () => setState(() => _isPressed = false),
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: AnimatedScale(
          scale: _isPressed ? 0.97 : ((_isHovered || widget.isHighlighted) ? 1.01 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (widget.isSelected || widget.isHighlighted)
                    ? AppTheme.primaryColor
                    : (_isHovered
                        ? AppTheme.primaryColor.withValues(alpha: 0.4)
                        : isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppTheme.borderLight),
                width: (widget.isSelected || widget.isHighlighted) || _isHovered ? 2.0 : 0.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: widget.isHighlighted
                      ? AppTheme.primaryColor.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: _isHovered ? 0.12 : 0.04),
                  blurRadius: widget.isHighlighted ? 16 : (_isHovered ? 16 : 4),
                  offset: Offset(0, widget.isHighlighted ? 6 : (_isHovered ? 8 : 2)),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: Padding(
                        padding: _getPaddingForViewMode(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getDisplayTitle(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimary,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                if (widget.note.isPinned)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.push_pin_rounded,
                                      size: 14,
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                if (widget.note.isLocked)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8),
                                    child: Icon(
                                      Icons.lock_rounded,
                                      size: 14,
                                      color: isDark ? Colors.white54 : Colors.grey,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Expanded(
                              child: Text(
                                _getDisplayContent(),
                                maxLines: _getMaxLinesForViewMode(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildPremiumFooter(isDark, timeString),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}';
  }

  Widget _buildPremiumFooter(bool isDark, String timeString) {
    return Row(
      children: [
        Icon(
          Icons.access_time_rounded,
          size: 12,
          color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
        ),
        const SizedBox(width: 4),
        Text(
          timeString,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
        ),
        const Spacer(),
        if (widget.note.collaborators.isNotEmpty)
          Icon(
            Icons.people_outline_rounded,
            size: 14,
            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
          ),
      ],
    );
  }

  EdgeInsets _getPaddingForViewMode() {
    switch (widget.viewMode) {
      case 'grid':
      case 'large-grid':
        return const EdgeInsets.all(12);
      case 'details':
      default:
        return const EdgeInsets.all(16);
    }
  }

  int _getMaxLinesForViewMode() {
    switch (widget.viewMode) {
      case 'grid':
        return 2;
      case 'large-grid':
        return 4;
      case 'details':
        return 3;
      default:
        return 2;
    }
  }
}

/// Custom Curve for damped physical shake animation
class ShakeCurve extends Curve {
  const ShakeCurve({this.count = 3.0});
  final double count;

  @override
  double transformInternal(double t) {
    return math.sin(t * count * 2 * math.pi) * (1 - t);
  }
}
