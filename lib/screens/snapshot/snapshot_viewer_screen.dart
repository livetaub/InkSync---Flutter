import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../utils/platform_helper.dart' as platform;
import '../../config/theme.dart';
import '../../services/auth_service.dart';
import '../../services/notes_service.dart';

/// Read-only viewer for note snapshots.
/// No login required — anyone with the link can view the frozen copy.
/// Desktop: side-by-side (marketing left, note right with internal scroll).
/// Mobile: branded header + floating scrollable note card.
/// Doubles as a viral landing page with CTA to drive signups.
class SnapshotViewerScreen extends StatefulWidget {
  final String token;

  const SnapshotViewerScreen({super.key, required this.token});

  @override
  State<SnapshotViewerScreen> createState() => _SnapshotViewerScreenState();
}

class _SnapshotViewerScreenState extends State<SnapshotViewerScreen> {
  Map<String, dynamic>? _snapshot;
  bool _isLoading = true;
  String? _error;

  static const _colorNames = [
    'yellow', 'orange', 'red', 'pink',
    'purple', 'blue', 'teal', 'green',
  ];

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  Future<void> _loadSnapshot() async {
    try {
      final response = await Supabase.instance.client
          .from('note_snapshots')
          .select()
          .eq('token', widget.token)
          .maybeSingle();

      setState(() {
        _snapshot = response;
        _isLoading = false;
        if (response == null) _error = 'Snapshot not found';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Could not load snapshot';
      });
    }
  }

  void _copyText() {
    if (_snapshot == null) return;

    final title = _snapshot!['title'] ?? '';
    final content = _snapshot!['content'] ?? '';
    final noteType = _snapshot!['note_type'] ?? 'text';

    String textToCopy;
    if (noteType == 'checklist') {
      final items = (_snapshot!['checklist_items'] as List<dynamic>?) ?? [];
      final itemsText = items.map((item) {
        final checked = item['checked'] == true;
        final text = item['text'] ?? '';
        return '${checked ? '☑' : '☐'} $text';
      }).join('\n');
      textToCopy = '$title\n\n$itemsText';
    } else {
      textToCopy = '$title\n\n$content';
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Text copied to clipboard'),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  String _getColorName(int index) {
    return index < _colorNames.length ? _colorNames[index] : 'yellow';
  }

  void _importToNotes() async {
    if (_snapshot == null) return;

    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      // Not logged in → redirect to login with import token
      final origin = platform.getLocationOrigin();
      platform.setLocationHref('$origin/login?import_snapshot=${widget.token}');
      return;
    }

    // User is logged in → import directly
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final newNote = await notesService.importFromSnapshot(_snapshot!);

      if (!mounted) return;

      if (newNote != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Note imported successfully!'),
              ],
            ),
            backgroundColor: AppTheme.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () {
                final origin = platform.getLocationOrigin();
                platform.setLocationHref('$origin/app');
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to import note'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to import note'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0D1117) : const Color(0xFFF0F2F5);

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBrandIcon(36),
              const SizedBox(height: 20),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              ),
            ],
          ),
        ),
      );
    }

    if (_error != null || _snapshot == null) {
      return _buildErrorState(isDark, bgColor);
    }

    return _buildSnapshotPage(isDark, bgColor);
  }

  Widget _buildErrorState(bool isDark, Color bgColor) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBrandIcon(48),
            const SizedBox(height: 32),
            Icon(
              Icons.link_off_rounded,
              size: 64,
              color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.grey.shade300,
            ),
            const SizedBox(height: 20),
            Text(
              'Snapshot Not Found',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This link may have expired or is invalid.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 32),
            _buildSignUpButton(),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MAIN LAYOUT
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildSnapshotPage(bool isDark, Color bgColor) {
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(isDark),
            Expanded(
              child: isDesktop
                  ? _buildDesktopLayout(isDark)
                  : _buildMobileLayout(isDark),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Top Bar ───────────────────────────────────────────────────────

  Widget _buildTopBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161B22) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => platform.openInNewTab('https://inksyncnote.com'),
              child: Row(
                children: [
                  _buildBrandIcon(22),
                  const SizedBox(width: 8),
                  Text(
                    'InkSync',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          // Import button
          OutlinedButton.icon(
            onPressed: _importToNotes,
            icon: const Icon(Icons.add_to_photos_rounded, size: 16),
            label: const Text('Import to Notes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? Colors.white70 : AppTheme.textPrimary,
              side: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.grey.shade300,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Copy Text button
          ElevatedButton.icon(
            onPressed: _copyText,
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy Text'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  DESKTOP: Note Left ← → Marketing Right
  //  MOBILE:  Note first (above fold) → Marketing below
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildDesktopLayout(bool isDark) {
    return Row(
      children: [
        // Left: Note card (scrollbar stays on the natural right edge of note)
        Expanded(
          flex: 5,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 0, 24),
            child: _buildFloatingNoteCard(isDark, maxWidth: 520),
          ),
        ),

        // Right: Marketing / CTA (scrollable, scrollbar on far right)
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 40),
            child: _buildMarketingContent(isDark, isDesktop: true),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Note card FIRST (visible above the fold)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 480),
              child: _buildFloatingNoteCard(isDark),
            ),
          ),

          const SizedBox(height: 32),

          // Marketing / CTA below
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _buildMarketingContent(isDark, isDesktop: false),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  FLOATING NOTE CARD with scroll-more hint
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildFloatingNoteCard(bool isDark, {double? maxWidth}) {
    final colorName = _getColorName(_snapshot!['color'] ?? 0);
    final headerColor = isDark
        ? AppTheme.noteColorsDark[colorName] ?? const Color(0xFF2D2D2D)
        : AppTheme.noteColors[colorName] ?? const Color(0xFFFAFAFA);
    final bodyColor = isDark
        ? AppTheme.noteBodyColorsDark[colorName] ?? AppTheme.bgPrimaryDark
        : AppTheme.noteHeaderColors[colorName] ?? AppTheme.bgPrimary;
    final lineColor = isDark ? Colors.white12 : const Color(0xFFE5EAF0);

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth ?? double.infinity),
      decoration: BoxDecoration(
        color: bodyColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.12),
            blurRadius: 48,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Note header (fixed)
          _buildNoteHeader(headerColor, isDark),

          // Note content (scrollable) with fade hint
          Flexible(
            child: _NoteContentWithScrollHint(
              bodyColor: bodyColor,
              lineColor: lineColor,
              isDark: isDark,
              snapshot: _snapshot!,
              buildNoteContent: _buildNoteContent,
              buildChecklistView: _buildChecklistView,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Note Header ───────────────────────────────────────────────────

  Widget _buildNoteHeader(Color headerColor, bool isDark) {
    final title = _snapshot!['title'] ?? '';
    final createdAt = _snapshot!['created_at'] != null
        ? DateTime.parse(_snapshot!['created_at'])
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      decoration: BoxDecoration(
        color: headerColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.link_rounded,
                  size: 12,
                  color: isDark ? Colors.white30 : AppTheme.textMuted,
                ),
                const SizedBox(width: 5),
                Text(
                  'Shared snapshot${createdAt != null ? ' · ${_formatDate(createdAt)}' : ''}',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.white30 : AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (title.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppTheme.textPrimary,
                letterSpacing: -0.5,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ─── Note Content with Lined Paper ─────────────────────────────────

  Widget _buildNoteContent(Color bodyColor, Color lineColor, bool isDark) {
    final content = _snapshot!['content'] ?? '';
    final noteType = _snapshot!['note_type'] ?? 'text';
    final checklistItems =
        (_snapshot!['checklist_items'] as List<dynamic>?) ?? [];

    return SizedBox(
      width: double.infinity,
      child: CustomPaint(
        painter: _SnapshotLinedPaperPainter(
          lineColor: lineColor,
          lineHeight: 28.0,
          topPadding: 16.0,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: noteType == 'checklist'
              ? _buildChecklistView(checklistItems, isDark)
              : SelectableText(
                  content,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                    height: 28.0 / 15.0,
                    letterSpacing: 0.1,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildChecklistView(List<dynamic> items, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: items.map((item) {
        final checked = item['checked'] == true;
        final text = item['text'] ?? '';
        return Container(
          height: 28,
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Icon(
                checked
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: checked
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.white30 : Colors.grey.shade400),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 15,
                    color: checked
                        ? (isDark ? Colors.white30 : Colors.grey.shade400)
                        : (isDark ? Colors.white70 : AppTheme.textSecondary),
                    decoration: checked ? TextDecoration.lineThrough : null,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  MARKETING / CTA CONTENT (shared by both layouts)
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildMarketingContent(bool isDark, {required bool isDesktop}) {
    return Column(
      mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        // Brand icon
        _buildBrandIcon(isDesktop ? 44 : 36),
        const SizedBox(height: 24),

        // Headline
        Text(
          'Your notes,\nbeautifully organized.',
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontSize: isDesktop ? 36 : 24,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimary,
            letterSpacing: -0.8,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 16),

        // Subheadline
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            'InkSync is a free note-taking app with real-time collaboration, '
            'cross-platform sync, checklists, tags, and beautiful themes. '
            'Available on web, iOS, and Android.',
            textAlign: isDesktop ? TextAlign.left : TextAlign.center,
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Feature pills
        Wrap(
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildFeaturePill('✍️ Rich Notes', isDark),
            _buildFeaturePill('✅ Checklists', isDark),
            _buildFeaturePill('🔄 Cross-Platform Sync', isDark),
            _buildFeaturePill('👥 Real-time Collab', isDark),
            _buildFeaturePill('🏷️ Tags & Colors', isDark),
            _buildFeaturePill('🔒 Note Locking', isDark),
            _buildFeaturePill('🌙 Dark Mode', isDark),
          ],
        ),
        const SizedBox(height: 36),

        // CTA Buttons
        Wrap(
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildSignUpButton(),
            _buildStoreButton(
              label: 'App Store',
              icon: Icons.apple_rounded,
              url: 'https://apps.apple.com/app/inksync',
              isDark: isDark,
            ),
            _buildStoreButton(
              label: 'Google Play',
              icon: Icons.android_rounded,
              url: 'https://play.google.com/store/apps/details?id=com.inksync.app',
              isDark: isDark,
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Footer
        Align(
          alignment: isDesktop ? Alignment.centerLeft : Alignment.center,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => platform.openInNewTab('https://inksyncnote.com'),
              child: Text(
                'inksyncnote.com',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white24 : Colors.grey.shade400,
                  decoration: TextDecoration.underline,
                  decorationColor: isDark ? Colors.white24 : Colors.grey.shade400,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════
  //  REUSABLE WIDGETS
  // ═══════════════════════════════════════════════════════════════════

  Widget _buildBrandIcon(double size) {
    return ShaderMask(
      shaderCallback: (bounds) => const LinearGradient(
        colors: [Color(0xFF1E88E5), Color(0xFF10D98C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(bounds),
      child: Icon(Icons.sync_rounded, color: Colors.white, size: size),
    );
  }

  Widget _buildSignUpButton() {
    return ElevatedButton.icon(
      onPressed: () {
        final origin = platform.getLocationOrigin();
        platform.openInNewTab('$origin/login');
      },
      icon: const Icon(Icons.person_add_rounded, size: 18),
      label: const Text('Sign Up Free'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildStoreButton({
    required String label,
    required IconData icon,
    required String url,
    required bool isDark,
  }) {
    return OutlinedButton.icon(
      onPressed: () => platform.openInNewTab(url),
      icon: Icon(icon, size: 20),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? Colors.white70 : AppTheme.textPrimary,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.grey.shade300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildFeaturePill(String label, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white54 : AppTheme.textSecondary,
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }
}

/// Lined paper painter for the snapshot note card
class _SnapshotLinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;
  final double topPadding;

  _SnapshotLinedPaperPainter({
    required this.lineColor,
    this.lineHeight = 28.0,
    this.topPadding = 16.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    double y = topPadding + lineHeight;
    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant _SnapshotLinedPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.topPadding != topPadding;
  }
}

/// Note content with a gradient fade + "scroll for more" hint overlay
class _NoteContentWithScrollHint extends StatefulWidget {
  final Color bodyColor;
  final Color lineColor;
  final bool isDark;
  final Map<String, dynamic> snapshot;
  final Widget Function(Color, Color, bool) buildNoteContent;
  final Widget Function(List<dynamic>, bool) buildChecklistView;

  const _NoteContentWithScrollHint({
    required this.bodyColor,
    required this.lineColor,
    required this.isDark,
    required this.snapshot,
    required this.buildNoteContent,
    required this.buildChecklistView,
  });

  @override
  State<_NoteContentWithScrollHint> createState() =>
      _NoteContentWithScrollHintState();
}

class _NoteContentWithScrollHintState extends State<_NoteContentWithScrollHint> {
  final ScrollController _scrollController = ScrollController();
  bool _showScrollHint = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkOverflow());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkOverflow() {
    if (!_scrollController.hasClients) return;
    final hasOverflow = _scrollController.position.maxScrollExtent > 0;
    if (hasOverflow != _showScrollHint) {
      setState(() => _showScrollHint = hasOverflow);
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final atBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 20;
    if (atBottom && _showScrollHint) {
      setState(() => _showScrollHint = false);
    } else if (!atBottom && !_showScrollHint) {
      setState(() => _showScrollHint = true);
    }
  }

  void _scrollDown() {
    _scrollController.animateTo(
      _scrollController.offset + 200,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          controller: _scrollController,
          child: widget.buildNoteContent(
            widget.bodyColor,
            widget.lineColor,
            widget.isDark,
          ),
        ),

        // Gradient fade + arrow hint at bottom
        if (_showScrollHint)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: _scrollDown,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.bodyColor.withValues(alpha: 0.0),
                        widget.bodyColor.withValues(alpha: 0.85),
                        widget.bodyColor,
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: widget.isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.06),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: widget.isDark ? Colors.white38 : AppTheme.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
