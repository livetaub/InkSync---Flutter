import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/ui_helper.dart';
import '../../services/notes_service.dart';
import '../../services/gemini_service.dart';
import '../../services/auth_service.dart';
import '../../services/calendar_service.dart';
import '../../services/notification_service.dart';
import '../../services/tag_service.dart';
import '../../config/theme.dart';
import '../subscription/mobile_paywall_screen.dart';
import '../../providers/selection_provider.dart';
import '../../utils/platform_helper.dart' as platform;

class NoteEditScreen extends StatefulWidget {
  final Note? note;
  final String noteType;
  final bool isEmbedded;
  final VoidCallback? onSave; // Callback when note is saved
  final String? initialSearchQuery;

  const NoteEditScreen({
    super.key,
    this.note,
    this.noteType = 'text',
    this.isEmbedded = false,
    this.onSave,
    this.initialSearchQuery,
  });

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late AuthService _authService;
  late NotesService _notesService;
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late TextEditingController _searchController;
  late String _noteType;
  late String _color;
  late bool _isPinned;
  late bool _isPinnedToNotifications;
  late bool _isLocked;
  String? _lockPassword;
  late List<ChecklistItem> _checklistItems;
  late List<Collaborator> _collaborators;
  String? _noteId;
  String? _createdBy;
  String? _ownerEmail;
  List<String> _tags = [];
  Timer? _autoSaveTimer;
  bool _hasChanges = false;
  bool _isSaving = false;
  bool _isUnlocked = false;
  bool _isEditing = false; // Notes open in read-only mode
  bool _newCollaboratorCanEdit =
      true; // Default permission for new collaborators

  // Track last saved text to avoid spurious saves on cursor movement
  String _lastSavedTitle = '';
  String _lastSavedContent = '';
  // Track last known text to avoid expensive recalculations on cursor movement
  String _lastKnownTitle = '';
  String _lastKnownContent = '';

  // Title auto-derive state
  late bool _titleSetManually;
  bool _isEditingTitle = false;
  final FocusNode _titleFocusNode = FocusNode();

  // Search state
  bool _showSearch = false;
  List<int> _searchMatches = [];
  int _currentMatchIndex = -1;
  final ScrollController _textScrollController = ScrollController();
  final FocusNode _contentFocusNode = FocusNode();

  // Checklist focus
  final List<FocusNode> _checklistFocusNodes = [];
  final List<TextEditingController> _checklistControllers = [];
  int _lastContentTapTime = 0;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _notesService = NotesService(_authService);
    _noteId = widget.note?.id;
    _createdBy = widget.note?.createdBy;
    _titleController = TextEditingController(text: widget.note?.title ?? '');
    _contentController = TextEditingController(
      text: widget.note?.content ?? '',
    );
    _searchController = TextEditingController();
    _noteType = widget.note?.type ?? widget.noteType;
    _color = widget.note?.color ?? 'yellow';
    _isPinned = widget.note?.isPinned ?? false;
    _isPinnedToNotifications = widget.note?.isPinnedToNotifications ?? false;
    _isLocked = widget.note?.isLocked ?? false;
    _lockPassword = widget.note?.lockPassword;
    _checklistItems = List.from(widget.note?.checklistItems ?? []);
    _collaborators = List.from(widget.note?.collaborators ?? []);
    _tags = List.from(widget.note?.tags ?? []);
    _titleSetManually = widget.note?.titleSetManually ?? false;
    _isEditing = widget.note == null; // New notes open in edit mode
    
    if (widget.note == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNoteLimit();
      });
    }

    _lastSavedTitle = _titleController.text;
    _lastSavedContent = _contentController.text;
    _lastKnownTitle = _titleController.text;
    _lastKnownContent = _contentController.text;

    // If title was not manually set and is empty, derive from content
    if (!_titleSetManually && _titleController.text.isEmpty) {
      _deriveTitle();
    }

    if (_noteType == 'checklist' && _checklistItems.isEmpty) {
      _checklistItems = [
        ChecklistItem(id: DateTime.now().millisecondsSinceEpoch.toString()),
      ];
    }

    _initChecklistControllers();

    // Lock DOM textarea metrics to match CanvasKit rendering (Web-only)
    if (kIsWeb) {
      try {
        // This is handled by web_helper.dart at the platform level
        // The CSS is injected during web initialization
      } catch (_) {}
    }

    if (_isLocked && !_isUnlocked && widget.note != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showUnlockDialog();
      });
    }

    // Track when user is directly editing the title field
    _titleFocusNode.addListener(() {
      _isEditingTitle = _titleFocusNode.hasFocus;
    });

    _titleController.addListener(_onTitleChanged);
    _contentController.addListener(_onTextChanged);
    _searchController.addListener(_performSearch);

    // Apply initial search query if provided
    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.isNotEmpty) {
      _showSearch = true;
      _searchController.text = widget.initialSearchQuery!;
    }

    _syncCollaboratorStatuses();
  }

  Future<void> _syncCollaboratorStatuses({Function(VoidCallback)? onModalState}) async {
    if (_noteId == null || _collaborators.isEmpty) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final statuses = await notesService.getInviteStatusesForNote(_noteId!);
      
      if (mounted && statuses.isNotEmpty) {
        bool changed = false;

        void updateState() {
          _ownerEmail = statuses.first['from_email'];
          for (int i = 0; i < _collaborators.length; i++) {
            final match = statuses.where(
              (s) => (s['to_email'] as String).toLowerCase().trim() ==
                  _collaborators[i].email.toLowerCase().trim(),
            );
            if (match.isNotEmpty) {
              final isAccepted = match.first['status'] == 'accepted';
              if (_collaborators[i].accepted != isAccepted) {
                _collaborators[i] = _collaborators[i].copyWith(
                  accepted: isAccepted,
                );
                changed = true;
              }
            }
          }
        }

        setState(updateState);
        if (onModalState != null) {
          onModalState(updateState);
        }

        // If the statuses changed, trigger an auto-save to update the note's JSON blob
        if (changed) {
          _onContentChanged();
        }
      }
    } catch (e) {
      debugPrint('Error syncing collaborator statuses: $e');
    }
  }

  void _initChecklistControllers() {
    for (var node in _checklistFocusNodes) {
      node.dispose();
    }
    for (var controller in _checklistControllers) {
      controller.dispose();
    }
    _checklistFocusNodes.clear();
    _checklistControllers.clear();

    for (var item in _checklistItems) {
      _checklistFocusNodes.add(FocusNode());
      _checklistControllers.add(TextEditingController(text: item.text));
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();

    // Auto-save when switching notes in embedded mode
    if (widget.isEmbedded && _hasChanges && !_isSaving) {
      _saveNoteSync();
    }

    _titleController.dispose();
    _contentController.dispose();
    _searchController.dispose();
    _textScrollController.dispose();
    _contentFocusNode.dispose();
    _titleFocusNode.dispose();
    for (var node in _checklistFocusNodes) {
      node.dispose();
    }
    for (var controller in _checklistControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Synchronous save for use in dispose - fires and forgets
  void _saveNoteSync() {
    final title = _titleController.text;

    if (_noteId != null) {
      _notesService.updateNote(_noteId!, {
        'title': title,
        'content': _noteType == 'text' ? _contentController.text : '',
        'type': _noteType,
        'color': _color,
        'isPinned': _isPinned,
        'isPinnedToNotifications': _isPinnedToNotifications,
        'isLocked': _isLocked,
        'lockPassword': _lockPassword,
        'checklistItems': _checklistItems.map((i) => i.toMap()).toList(),
        'collaborators': _collaborators.map((c) => c.toMap()).toList(),
        'tags': _tags,
        'titleSetManually': _titleSetManually,
      });
      if (!kIsWeb && _isPinnedToNotifications) {
        final content = _noteType == 'text'
            ? _contentController.text
            : _checklistItems.map((i) => '${i.checked ? "☑" : "☐"} ${i.text}').join('\n');
        NotificationService.instance.pinNote(
          noteId: _noteId!,
          title: title,
          body: content,
        );
      }
      widget.onSave?.call();
    } else {
      // Fire and forget creation of a new note if closed immediately
      final newNote = Note(
        title: title,
        content: _noteType == 'text' ? _contentController.text : '',
        type: _noteType,
        color: _color,
        isPinned: _isPinned,
        isPinnedToNotifications: _isPinnedToNotifications,
        isLocked: _isLocked,
        lockPassword: _lockPassword,
        checklistItems: _noteType == 'checklist' ? _checklistItems : [],
        collaborators: _collaborators,
        createdBy: _authService.currentUserId,
        tags: _tags,
        titleSetManually: _titleSetManually,
      );
      _notesService.createNote(newNote).then((created) {
        if (!kIsWeb && _isPinnedToNotifications && created != null && created.id != null) {
          final content = created.type == 'text'
              ? created.content
              : created.checklistItems.map((i) => '${i.checked ? "☑" : "☐"} ${i.text}').join('\n');
          NotificationService.instance.pinNote(
            noteId: created.id!,
            title: created.title,
            body: content,
          );
        }
        widget.onSave?.call();
      });
    }
  }

  Future<void> _toggleNotificationPin() async {
    if (kIsWeb) return;
    HapticFeedback.mediumImpact();

    if (_noteId == null) {
      await _saveNote();
    }

    if (_noteId == null) {
      return;
    }

    final title = _titleController.text;
    final content = _noteType == 'text'
        ? _contentController.text
        : _checklistItems.map((i) => '${i.checked ? "☑" : "☐"} ${i.text}').join('\n');

    try {
      if (_isPinnedToNotifications) {
        await NotificationService.instance.unpinNote(_noteId!);
        setState(() {
          _isPinnedToNotifications = false;
        });
      } else {
        await NotificationService.instance.pinNote(
          noteId: _noteId!,
          title: title,
          body: content,
        );
        setState(() {
          _isPinnedToNotifications = true;
        });
      }

      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      await notesService.updateNote(_noteId!, {
        'isPinnedToNotifications': _isPinnedToNotifications,
      });

      widget.onSave?.call();
    } catch (e) {
      debugPrint('Error toggling notification pin: $e');
    }
  }

  /// Called when user types in the title field
  void _onTitleChanged() {
    // If user is actively focused on the title field, mark as manually set
    if (_isEditingTitle) {
      _titleSetManually = true;
    }
    _onTextChanged();
  }

  /// Derive title from first line of content, limited to 20 characters
  bool get _canUserEdit {
    if (widget.note == null) return true;
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;
    final email = authService.currentUserEmail;

    // Owner check: null/empty createdBy means we're the owner
    // (consistent with _isCreator logic)
    if (_createdBy == null || _createdBy!.isEmpty || _createdBy == userId) {
      return true;
    }

    if (email != null) {
      final matches = _collaborators.where(
        (c) => c.email.toLowerCase().trim() == email.toLowerCase().trim(),
      );
      if (matches.isNotEmpty) {
        return matches.first.canEdit;
      }
    }
    return false;
  }

  Widget _buildViewOnlyBanner() {
    if (_canUserEdit) return const SizedBox.shrink();
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.amber.withValues(alpha: 0.15) : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.visibility_outlined, size: 20, color: Colors.amber.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'View-Only Access',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber.shade800,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'You have view-only permissions. You cannot edit this note.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.amber.shade600 : Colors.amber.shade900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _deriveTitle() {
    String firstLine = '';
    if (_noteType == 'checklist' && _checklistItems.isNotEmpty) {
      firstLine = _checklistItems.first.text.trim();
    } else {
      final content = _contentController.text.trim();
      if (content.isNotEmpty) {
        firstLine = content.split('\n').first.trim();
      }
    }

    final derived = firstLine.length > 20
        ? firstLine.substring(0, 20)
        : firstLine;

    // Only update if different to avoid infinite loops
    if (_titleController.text != derived) {
      _titleController.removeListener(_onTitleChanged);
      _titleController.text = derived;
      _titleController.addListener(_onTitleChanged);
    }
  }

  void _onTextChanged() {
    // Check if text actually changed (not just cursor movement)
    final currentTitle = _titleController.text;
    final currentContent = _contentController.text;
    if (currentTitle == _lastKnownTitle && currentContent == _lastKnownContent) {
      return; // Cursor moved, not a real change
    }

    _lastKnownTitle = currentTitle;
    _lastKnownContent = currentContent;

    // Auto-derive title from content when not manually set
    if (!_titleSetManually) {
      _deriveTitle();
    }

    _onContentChanged();
  }

  void _onContentChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }

    // Debounced auto-save: waits 10 seconds after last change
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(seconds: 10), () {
      if (_hasChanges && !_isSaving) {
        _lastSavedTitle = _titleController.text;
        _lastSavedContent = _contentController.text;
        _saveNote();
      }
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      // Today - show time
      final hour = date.hour;
      final minute = date.minute.toString().padLeft(2, '0');
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return 'Today $displayHour:$minute $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  bool get _isCreator {
    final authService = Provider.of<AuthService>(context, listen: false);
    return _createdBy == null || _createdBy == authService.currentUserId;
  }

  Future<void> _saveNote() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    try {
      final title = _titleController.text;

      if (_noteId == null) {
        final newNote = Note(
          title: title,
          content: _noteType == 'text' ? _contentController.text : '',
          type: _noteType,
          color: _color,
          isPinned: _isPinned,
          isPinnedToNotifications: _isPinnedToNotifications,
          isLocked: _isLocked,
          lockPassword: _lockPassword,
          checklistItems: _noteType == 'checklist' ? _checklistItems : [],
          collaborators: _collaborators,
          createdBy: _authService.currentUserId,
          tags: _tags,
          titleSetManually: _titleSetManually,
        );
        final created = await _notesService.createNote(newNote);
        _noteId = created?.id;
        _createdBy = _authService.currentUserId;
      } else {
        await _notesService.updateNote(_noteId!, {
          'title': title,
          'content': _noteType == 'text' ? _contentController.text : '',
          'type': _noteType,
          'color': _color,
          'isPinned': _isPinned,
          'isPinnedToNotifications': _isPinnedToNotifications,
          'isLocked': _isLocked,
          'lockPassword': _lockPassword,
          'checklistItems': _checklistItems.map((i) => i.toMap()).toList(),
          'collaborators': _collaborators.map((c) => c.toMap()).toList(),
          'tags': _tags,
          'titleSetManually': _titleSetManually,
        });
      }

      if (!kIsWeb && _isPinnedToNotifications && _noteId != null) {
        final content = _noteType == 'text'
            ? _contentController.text
            : _checklistItems.map((i) => '${i.checked ? "☑" : "☐"} ${i.text}').join('\n');
        await NotificationService.instance.pinNote(
          noteId: _noteId!,
          title: title,
          body: content,
        );
      }

      setState(() {
        _hasChanges = false;
        _isSaving = false;
      });

      // Notify parent to refresh list
      widget.onSave?.call();
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        showErrorSnackBar(context, 'Error saving: $e');
      }
    }
  }

  // Search functionality
  void _performSearch() {
    final query = _searchController.text.toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _searchMatches = [];
        _currentMatchIndex = -1;
      });
      return;
    }

    final text = _contentController.text.toLowerCase();
    final matches = <int>[];
    int index = 0;
    while ((index = text.indexOf(query, index)) != -1) {
      matches.add(index);
      index += query.length;
    }

    setState(() {
      _searchMatches = matches;
      _currentMatchIndex = matches.isNotEmpty ? 0 : -1;
    });

    // Don't steal focus when typing in search field
    _scrollToMatch(requestFocus: false);
  }

  void _scrollToMatch({bool requestFocus = true}) {
    if (_currentMatchIndex >= 0 && _currentMatchIndex < _searchMatches.length) {
      final matchPos = _searchMatches[_currentMatchIndex];

      // Calculate line number of match to scroll to
      final textBefore = _contentController.text.substring(0, matchPos);
      final lineNumber = '\n'.allMatches(textBefore).length;
      const lineHeight = 28.0;

      // Scroll to match position (with some offset for visibility)
      final scrollPosition = (lineNumber * lineHeight).clamp(
        0.0,
        _textScrollController.hasClients
            ? _textScrollController.position.maxScrollExtent
            : double.infinity,
      );

      if (_textScrollController.hasClients) {
        _textScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    }
  }

  void _nextMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex = (_currentMatchIndex + 1) % _searchMatches.length;
    });
    _scrollToMatch();
  }

  void _prevMatch() {
    if (_searchMatches.isEmpty) return;
    setState(() {
      _currentMatchIndex =
          (_currentMatchIndex - 1 + _searchMatches.length) %
          _searchMatches.length;
    });
    _scrollToMatch();
  }

  /// Builds content with highlighted search matches as RichText
  Widget _buildHighlightedContent(bool isDark) {
    const double fontSize = 16.0;
    const double lineHeight = 28.0;
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontFamily: 'Inter',
      color: isDark ? Colors.white : AppTheme.textPrimary,
      leadingDistribution: TextLeadingDistribution.even,
    );
    final strutStyle = const StrutStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      forceStrutHeight: true,
      leadingDistribution: TextLeadingDistribution.even,
    );
    
    final text = _contentController.text;
    final query = _searchController.text.toLowerCase();

    if (query.isEmpty || _searchMatches.isEmpty) {
      // No search - show normal text
      return SelectableText(
        text,
        style: textStyle,
        strutStyle: strutStyle,
      );
    }

    // Build TextSpans with highlights
    final spans = <TextSpan>[];
    int lastEnd = 0;

    // Sort matches to process in order
    final sortedMatches = List<int>.from(_searchMatches)..sort();

    for (int i = 0; i < sortedMatches.length; i++) {
      final matchPos = sortedMatches[i];
      final isCurrentMatch =
          _currentMatchIndex >= 0 &&
          _currentMatchIndex < _searchMatches.length &&
          _searchMatches[_currentMatchIndex] == matchPos;

      // Add text before this match (normal style)
      if (matchPos > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, matchPos)));
      }

      // Add highlighted match
      spans.add(
        TextSpan(
          text: text.substring(
            matchPos,
            matchPos + _searchController.text.length,
          ),
          style: TextStyle(
            backgroundColor: isCurrentMatch
                ? Colors.orange.withValues(alpha: 0.6)
                : Colors.yellow.withValues(alpha: 0.5),
          ),
        ),
      );

      lastEnd = matchPos + _searchController.text.length;
    }

    // Add remaining text after last match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return SelectableText.rich(
      TextSpan(
        children: spans,
        style: textStyle,
      ),
      strutStyle: strutStyle,
    );
  }

  void _showUnlockDialog() {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: AppTheme.primaryColor),
            SizedBox(width: 8),
            Text('Locked Note'),
          ],
        ),
        content: Container(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Enter password to view this note'),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'Password',
                  prefixIcon: Icon(Icons.key),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close unlock dialog
                    _handleForgotNotePassword();
                  },
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (passwordController.text == _lockPassword) {
                setState(() => _isUnlocked = true);
                Navigator.pop(context);
              } else {
                showErrorSnackBar(context, 'Incorrect password');
              }
            },
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
  }

  void _handleForgotNotePassword() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (!authService.isLoggedIn) {
      showErrorSnackBar(context, 'Cannot reset note password in guest mode. Please register/log in.');
      _showUnlockDialog();
      return;
    }

    final email = authService.currentUserEmail;
    if (email == null) {
      _showUnlockDialog();
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Note Password'),
        content: Text(
          'We will send a password reset verification email to $email. '
          'Verifying your identity will remove the lock on this note. '
          'Would you like to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Send Email'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await Supabase.instance.client.rpc(
          'request_note_unlock',
          params: {
            'p_note_id': _noteId,
            'p_email': email,
            'p_origin': kIsWeb ? platform.getLocationOrigin() : 'https://app.inksyncnote.com',
          },
        );

        if (mounted) {
          showSuccessSnackBar(context, 'Reset email sent! Please check your inbox.');
        }
      } catch (e) {
        if (mounted) {
          showErrorSnackBar(context, 'Error sending email: $e');
        }
      }
    } else {
      _showUnlockDialog();
    }
  }

  void _showLockDialog() {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  _isLocked ? Icons.lock_open : Icons.lock,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(width: 8),
                Text(_isLocked ? 'Remove Lock' : 'Lock Note'),
              ],
            ),
            content: Container(
              width: 380,
              child: _isLocked
                  ? Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Enter password to remove lock from this note:'),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Icon(Icons.key),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter the password';
                              }
                              if (value != _lockPassword) {
                                return 'Incorrect password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () {
                                Navigator.pop(context); // Close remove lock dialog
                                _handleForgotNotePassword();
                              },
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : Form(
                      key: formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Set a password to protect this note'),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              prefixIcon: Icon(Icons.key),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter a password';
                              }
                              if (value.length < 4) {
                                return 'Password must be at least 4 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: confirmPasswordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Confirm Password',
                              prefixIcon: Icon(Icons.key),
                            ),
                            validator: (value) {
                              if (value != passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (_isLocked) {
                    if (formKey.currentState?.validate() == true) {
                      setState(() {
                        _isLocked = false;
                        _lockPassword = null;
                      });
                      _onContentChanged();
                      await _saveNote();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  } else {
                    if (formKey.currentState?.validate() == true) {
                      setState(() {
                        _isLocked = true;
                        _lockPassword = passwordController.text;
                        _isUnlocked = true;
                      });
                      _onContentChanged();
                      await _saveNote();
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    }
                  }
                },
                child: Text(_isLocked ? 'Remove' : 'Lock'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showUpgradePaywall(String featureName, String message) {
    if (!mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MobilePaywallScreen(featureContext: featureName),
      ),
    );
  }

  Future<void> _checkNoteLimit() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final userId = authService.currentUserId;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client.from('profiles').select('account_type').eq('id', userId).single();
      final accountType = profile['account_type'] ?? 'free';
      
      final pricing = await Supabase.instance.client.from('global_pricing').select('notes_limit').eq('plan_id', accountType).single();
      final limit = pricing['notes_limit'] as int? ?? 75; // Default free limit
      
      final notes = await NotesService(authService).getActiveNotes();
      final count = notes.where((n) => n.createdBy == userId).length;

      if (count >= limit) {
        if (!mounted) return;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            final isDark = Theme.of(context).brightness == Brightness.dark;
            return Dialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.note_add_rounded, color: Colors.amber, size: 32),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Note Limit Reached',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'You have reached your limit of $limit notes. Upgrade your plan to create more notes, or delete some existing notes.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context); // Close NoteEditScreen
                            },
                            child: Text('Go Back', style: TextStyle(color: isDark ? Colors.white54 : AppTheme.textMuted)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context); // Close dialog
                              Navigator.pop(context); // Close NoteEditScreen
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const MobilePaywallScreen()),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: const Text('Upgrade Now', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      }
    } catch (e) {
      debugPrint('Error checking note limit: $e');
    }
  }

  Future<void> _showCollaboratorsDialog() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client.from('profiles').select('account_type').eq('id', userId).single();
      final accountType = profile['account_type'] ?? 'free';

      if (accountType == 'free') {
        if (mounted) _showUpgradePaywall('Real-Time Collaboration', 'Upgrade your subscription to work with friends and colleagues in real time.');
        return;
      }

      _showCollaboratorsDialogSheet();
    } catch (e) {
      debugPrint('Error checking collaboration limits: $e');
      _showCollaboratorsDialogSheet(); // Fallback
    }
  }

  void _shareInviteLink(String inviteeEmail) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final senderEmail = authService.currentUserEmail ?? 'Someone';
    final noteTitle = _titleController.text.isEmpty
        ? 'Untitled Note'
        : _titleController.text;

    final message = '✉️ You\'ve been invited to collaborate!\n\n'
        '$senderEmail invited you to collaborate on "$noteTitle".\n\n'
        'Sign in to your InkSync account with $inviteeEmail to accept the invite at:\n'
        '👉 https://app.inksyncnote.com\n\n'
        'Don\'t have an account yet? Create one for free!\n'
        'inksyncnote.com is a free cross-platform note-taking app.';

    // Copy to clipboard first (especially useful on desktop)
    Clipboard.setData(ClipboardData(text: message));
    showSuccessSnackBar(context, 'Invite link copied to clipboard');

    // Also open native share sheet
    Share.share(message);
  }

  void _showCollaboratorsDialogSheet() {
    final emailController = TextEditingController();
    bool isLoading = false;

    StateSetter? modalState;

    // Sync live invite statuses from the database and update dialog when ready
    _syncCollaboratorStatuses(
      onModalState: (update) {
        if (modalState != null) {
          modalState!(update);
        }
      },
    );

    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          modalState = setModalState;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 40,
              vertical: 60,
            ),
            child: Container(
              width: 420,
              constraints: const BoxConstraints(maxHeight: 520),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.people_alt_rounded,
                            color: AppTheme.primaryColor,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Share & Collaborate',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (_isCreator || _ownerEmail != null)
                                Text(
                                  _isCreator ? 'Created by you' : 'Created by $_ownerEmail',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.only(
                        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Add collaborator section (only for creator)
                          if (_isCreator) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invite someone',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? Colors.white70
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 10),

                                  // Email input with permission selector
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.05)
                                          : Colors.grey.shade50,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: isDark
                                            ? Colors.white12
                                            : Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: TextField(
                                            controller: emailController,
                                            keyboardType:
                                                TextInputType.emailAddress,
                                            style: const TextStyle(
                                              fontSize: 14,
                                            ),
                                            decoration: InputDecoration(
                                              hintText: 'Enter email address',
                                              hintStyle: TextStyle(
                                                color: Colors.grey.shade400,
                                              ),
                                              prefixIcon: Icon(
                                                Icons.mail_outline_rounded,
                                                color: Colors.grey.shade400,
                                                size: 20,
                                              ),
                                              border: InputBorder.none,
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 12,
                                                  ),
                                            ),
                                          ),
                                        ),

                                        // Permission dropdown
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                          margin: const EdgeInsets.only(
                                            right: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _newCollaboratorCanEdit
                                                ? Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: DropdownButtonHideUnderline(
                                            child: DropdownButton<bool>(
                                              value: _newCollaboratorCanEdit,
                                              isDense: true,
                                              icon: Icon(
                                                Icons.keyboard_arrow_down,
                                                size: 18,
                                                color: _newCollaboratorCanEdit
                                                    ? Colors.blue
                                                    : Colors.grey,
                                              ),
                                              items: [
                                                DropdownMenuItem(
                                                  value: true,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.edit,
                                                        size: 14,
                                                        color: Colors
                                                            .blue
                                                            .shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Editor',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .blue
                                                              .shade600,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                DropdownMenuItem(
                                                  value: false,
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        Icons.visibility,
                                                        size: 14,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        'Viewer',
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(
                                                    () =>
                                                        _newCollaboratorCanEdit =
                                                            value,
                                                  );
                                                  setModalState(() {});
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  // Send invite button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: isLoading
                                          ? null
                                          : () async {
                                              final email = emailController.text
                                                  .trim()
                                                  .toLowerCase();
                                              if (email.isEmpty ||
                                                  !email.contains('@')) {
                                                showErrorSnackBar(context, 'Please enter a valid email');
                                                return;
                                              }

                                              final existingIndex = _collaborators.indexWhere(
                                                (c) => c.email.toLowerCase().trim() == email,
                                              );

                                              if (existingIndex != -1) {
                                                showErrorSnackBar(context, 'User is already invited. Manage their permissions from the list below.');
                                                return;
                                              }

                                              setModalState(
                                                () => isLoading = true,
                                              );

                                              try {
                                                // Save note first if needed
                                                if (_noteId == null) {
                                                  await _saveNote();
                                                }

                                                if (_noteId != null) {
                                                  // Add collaborator to local list FIRST
                                                  setState(() {
                                                    _collaborators.add(
                                                      Collaborator(
                                                        email: email,
                                                        accepted: false,
                                                        canEdit:
                                                            _newCollaboratorCanEdit,
                                                      ),
                                                    );
                                                  });
                                                  setModalState(() {});
                                                  emailController.clear();
                                                  _onContentChanged();

                                                  // Try to send invite (non-blocking)
                                                  try {
                                                    final authService =
                                                        Provider.of<
                                                          AuthService
                                                        >(
                                                          context,
                                                          listen: false,
                                                        );
                                                    final notesService =
                                                        NotesService(
                                                          authService,
                                                        );

                                                    await notesService
                                                        .sendCollaborationInvite(
                                                          noteId: _noteId!,
                                                          noteTitle:
                                                              _titleController
                                                                  .text
                                                                  .isEmpty
                                                              ? 'Untitled Note'
                                                              : _titleController
                                                                    .text,
                                                          inviteeEmail: email,
                                                          canEdit:
                                                              _newCollaboratorCanEdit,
                                                        );

                                                    if (mounted) {
                                                      showSuccessSnackBar(context, '$email added');
                                                    }
                                                  } catch (inviteError) {
                                                    // Invite failed but user was still added
                                                    debugPrint(
                                                      '[ERROR] INVITE: $inviteError',
                                                    );
                                                    if (mounted) {
                                                      showSuccessSnackBar(context, '$email added (notification pending)');
                                                    }
                                                  }
                                                }
                                              } catch (e) {
                                                if (mounted) {
                                                  showErrorSnackBar(context, 'Error: $e');
                                                }
                                              } finally {
                                                setModalState(
                                                  () => isLoading = false,
                                                );
                                              }
                                            },
                                      icon: isLoading
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.send_rounded,
                                              size: 18,
                                            ),
                                      label: Text(
                                        isLoading
                                            ? 'Sending...'
                                            : 'Send Invite',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppTheme.primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 20),
                            Divider(color: Colors.grey.shade200, height: 1),
                          ],

                          // Collaborators list
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                            child: Row(
                              children: [
                                Text(
                                  'People with access',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white70
                                        : Colors.grey.shade700,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${_collaborators.length + 1} people',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Owner
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppTheme.primaryColor
                                    .withValues(alpha: 0.15),
                                child: const Icon(
                                  Icons.person,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                              ),
                              title: Text(
                                _isCreator ? 'You (Owner)' : (_ownerEmail ?? 'Owner'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'Owner',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Collaborators
                          if (_collaborators.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.group_add_outlined,
                                    size: 40,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'No collaborators yet',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...List.generate(_collaborators.length, (index) {
                              final collab = _collaborators[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: collab.accepted
                                        ? Colors.green.withValues(alpha: 0.15)
                                        : Colors.red.withValues(alpha: 0.15),
                                    child: Icon(
                                      collab.accepted
                                          ? Icons.check
                                          : Icons.schedule,
                                      color: collab.accepted
                                          ? Colors.green
                                          : Colors.red,
                                      size: 18,
                                    ),
                                  ),
                                  title: Text(
                                    collab.email,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: collab.accepted
                                          ? Colors.green.shade700
                                          : null,
                                    ),
                                  ),
                                  subtitle: Text(
                                    collab.accepted
                                        ? 'Accepted'
                                        : 'Pending invite',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: collab.accepted
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                  trailing: _isCreator
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // Permission dropdown
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: collab.canEdit
                                                    ? Colors.blue.withValues(
                                                        alpha: 0.1,
                                                      )
                                                    : Colors.grey.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: DropdownButtonHideUnderline(
                                                child: DropdownButton<bool>(
                                                  value: collab.canEdit,
                                                  isDense: true,
                                                  icon: Icon(
                                                    Icons.keyboard_arrow_down,
                                                    size: 16,
                                                    color: collab.canEdit
                                                        ? Colors.blue
                                                        : Colors.grey,
                                                  ),
                                                  items: [
                                                    DropdownMenuItem(
                                                      value: true,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.edit,
                                                            size: 12,
                                                            color: Colors
                                                                .blue
                                                                .shade600,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Editor',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .blue
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    DropdownMenuItem(
                                                      value: false,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Icon(
                                                            Icons.visibility,
                                                            size: 12,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                          const SizedBox(
                                                            width: 4,
                                                          ),
                                                          Text(
                                                            'Viewer',
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                  onChanged: (value) async {
                                                    if (value != null) {
                                                      if (_noteId != null) {
                                                        final authService = Provider.of<AuthService>(context, listen: false);
                                                        final notesService = NotesService(authService);
                                                        await notesService.updateCollaboratorPermission(_noteId!, collab.email, value);
                                                      }

                                                      setState(() {
                                                        _collaborators[index] =
                                                            collab.copyWith(
                                                              canEdit: value,
                                                            );
                                                      });
                                                      setModalState(() {});
                                                      _onContentChanged();
                                                    }
                                                  },
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 4),

                                            // Share invite link button
                                            IconButton(
                                              icon: Icon(
                                                Icons.share_outlined,
                                                size: 18,
                                                color: Colors.blue.shade300,
                                              ),
                                              tooltip: 'Share invite link',
                                              onPressed: () => _shareInviteLink(collab.email),
                                            ),
                                            const SizedBox(width: 4),

                                            // Remove button
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 18,
                                                color: Colors.red.shade300,
                                              ),
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Remove Collaborator?',
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to remove ${collab.email} from this note?',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        style:
                                                            TextButton.styleFrom(
                                                              foregroundColor:
                                                                  Colors.red,
                                                            ),
                                                        child: const Text(
                                                          'Remove',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );

                                                if (confirm == true) {
                                                  if (_noteId != null) {
                                                    final authService = Provider.of<AuthService>(context, listen: false);
                                                    final notesService = NotesService(authService);
                                                    await notesService.revokeInvite(_noteId!, collab.email);
                                                  }

                                                  setState(
                                                    () => _collaborators
                                                        .removeAt(index),
                                                  );
                                                  setModalState(() {});
                                                  _onContentChanged();
                                                }
                                              },
                                            ),
                                          ],
                                        )
                                      : Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: collab.canEdit
                                                ? Colors.blue.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.grey.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                          ),
                                          child: Text(
                                            collab.canEdit
                                                ? 'Editor'
                                                : 'Viewer',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: collab.canEdit
                                                  ? Colors.blue
                                                  : Colors.grey.shade600,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                ),
                              );
                            }),

                          // Leave button for non-creators
                          if (!_isCreator) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => _leaveNote(context),
                                  icon: const Icon(
                                    Icons.exit_to_app,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                  label: const Text('Leave this note'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          if (_isCreator) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Force immediate save so the note's JSON blob syncs with the database permissions
                                    if (_hasChanges) {
                                      _lastSavedTitle = _titleController.text;
                                      _lastSavedContent = _contentController.text;
                                      _saveNote();
                                    }
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.check_circle_outline, size: 20),
                                  label: const Text(
                                    'Save & Close',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],

                          SizedBox(
                            height: MediaQuery.of(context).padding.bottom + 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _leaveNote(BuildContext ctx) async {
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Leave Note?'),
        content: const Text(
          'You will no longer have access to this shared note.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Leave', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      if (_noteId != null) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final notesService = NotesService(authService);
        await notesService.leaveNote(_noteId!);
      }

      Navigator.pop(ctx); // Close dialog
      Navigator.pop(context); // Go back
      showSuccessSnackBar(context, 'You left the note');
    }
  }

  void _showColorPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    showAdaptiveModal(
      context: context,
      backgroundColor: isDesktop ? null : Theme.of(context).scaffoldBackgroundColor,
      child: Builder(
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: isDesktop
                ? (isDark ? const Color(0xFF1A1D21) : Colors.white)
                : Theme.of(context).scaffoldBackgroundColor,
            borderRadius: isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isDesktop) ...[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              const Text(
                'Choose Color',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppTheme.noteColors.keys
                    .where((key) => !['teal', 'gray', 'white'].contains(key))
                    .map((key) {
                      final isSelected = _color == key;
                      final darkerColor = isDark 
                          ? AppTheme.noteColorsDark[key] ?? Colors.grey 
                          : AppTheme.noteColors[key] ?? Colors.grey;
                      final lighterColor = isDark 
                          ? AppTheme.noteBodyColorsDark[key] ?? Colors.white 
                          : AppTheme.noteHeaderColors[key] ?? Colors.white;

                      return GestureDetector(
                        onTap: () async {
                          setState(() => _color = key);
                          _onContentChanged();
                          await _saveNote();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: lighterColor,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : darkerColor,
                              width: isSelected ? 3 : 2,
                            ),
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                )
                              : null,
                        ),
                      );
                    })
                    .toList(),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _showTagsSheet() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final tagService = TagService(authService);
    
    // Fetch available tags for this note type
    final availableTags = await tagService.getTagsByType(_noteType);
    
    if (!mounted) return;

    final controller = TextEditingController();
    final isDesktop = MediaQuery.of(context).size.width > 800;
    
    showAdaptiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDesktop ? null : Theme.of(context).scaffoldBackgroundColor,
      child: StatefulBuilder(
        builder: (ctx, setSheetState) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Container(
            decoration: BoxDecoration(
              color: isDesktop
                  ? (isDark ? const Color(0xFF1A1D21) : Colors.white)
                  : Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: isDesktop
                  ? BorderRadius.circular(20)
                  : const BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              left: 24,
              right: 24,
              top: 24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isDesktop) ...[
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                const Row(
                  children: [
                    Icon(Icons.label_outline, color: AppTheme.primaryColor),
                    SizedBox(width: 8),
                    Text(
                      'Manage Tags',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // List of available tags
                if (availableTags.isNotEmpty) ...[
                  const Text(
                    'Select existing tags:',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = _tags.any((t) => t.toLowerCase() == tag.name.toLowerCase());
                      return FilterChip(
                        label: Text(tag.name),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                        checkmarkColor: AppTheme.primaryColor,
                        onSelected: (selected) async {
                          setSheetState(() {
                            if (selected) {
                              if (!_tags.contains(tag.name)) _tags.add(tag.name);
                            } else {
                              _tags.removeWhere((t) => t.toLowerCase() == tag.name.toLowerCase());
                            }
                          });
                          setState(() {});
                          _onContentChanged();
                          await _saveNote();
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                const Text(
                  'Or create a new tag:',
                  style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        autofocus: availableTags.isEmpty,
                        decoration: InputDecoration(
                          hintText: 'New tag name...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: isDark 
                              ? Colors.white.withValues(alpha: 0.05) 
                              : Colors.grey.shade100,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (value) async {
                          final newTag = value.trim();
                          if (newTag.isNotEmpty && !_tags.any((t) => t.toLowerCase() == newTag.toLowerCase())) {
                            // Check if it exists globally
                            if (!availableTags.any((t) => t.name.toLowerCase() == newTag.toLowerCase())) {
                              await tagService.createTag(newTag, type: _noteType);
                            }
                            
                            setSheetState(() {
                              _tags.add(newTag);
                            });
                            setState(() {});
                            _onContentChanged();
                            await _saveNote();
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.add_rounded, color: Colors.white),
                        onPressed: () async {
                          final newTag = controller.text.trim();
                          if (newTag.isNotEmpty && !_tags.any((t) => t.toLowerCase() == newTag.toLowerCase())) {
                            if (!availableTags.any((t) => t.name.toLowerCase() == newTag.toLowerCase())) {
                              await tagService.createTag(newTag, type: _noteType);
                            }
                            
                            setSheetState(() {
                              _tags.add(newTag);
                            });
                            setState(() {});
                            _onContentChanged();
                            await _saveNote();
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showWritingAssist() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      final profile = await Supabase.instance.client.from('profiles').select('account_type, ai_credits_used').eq('id', userId).single();
      final accountType = profile['account_type'] ?? 'free';
      final usedCredits = profile['ai_credits_used'] as int? ?? 0;

      final pricing = await Supabase.instance.client.from('global_pricing').select('ai_credits_limit').eq('plan_id', accountType).single();
      int limit = pricing['ai_credits_limit'] as int? ?? 0;

      // Allow 3 lifetime free samples for free users
      if (accountType == 'free' && limit < 3) {
        limit = 3;
      }

      if (usedCredits >= limit) {
        if (accountType == 'free') {
           if (mounted) _showUpgradePaywall('AI Writing Assist', 'You have used all your free AI credits. Upgrade your subscription to unlock unlimited AI writing assistance.');
        } else {
           if (mounted) showErrorSnackBar(context, 'You have reached your plan\'s AI assist limit.');
        }
        return;
      } else if (accountType == 'free') {
         if (mounted) {
           showSuccessSnackBar(context, 'AI Writing Assist is a premium feature. You have ${limit - usedCredits} free uses included in your plan.');
         }
      }

      _showWritingAssistSheet();
    } catch (e) {
      debugPrint('Error checking AI limits: $e');
      _showWritingAssistSheet(); // Fallback
    }
  }

  void _showWritingAssistSheet() {
    final selection = _contentController.selection;
    // Require user to select text
    if (!selection.isValid ||
        selection.baseOffset == selection.extentOffset ||
        selection.start < 0 ||
        selection.end > _contentController.text.length) {
      showErrorSnackBar(context, 'Select the text you want AI to enhance');
      return;
    }

    final textToProcess = _contentController.text.substring(
      selection.start,
      selection.end,
    );
    const hasSelection = true;

    if (textToProcess.trim().isEmpty) {
      showErrorSnackBar(context, 'Selected text is empty');
      return;
    }

    final isDesktop = MediaQuery.of(context).size.width > 800;

    showAdaptiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDesktop ? null : Colors.transparent,
      child: Builder(
        builder: (ctx) => AIWritingAssistSheet(
          text: textToProcess,
          hasSelection: hasSelection,
          onInsert: (result) {
            if (hasSelection) {
              final start = _contentController.selection.start;
              final end = _contentController.selection.end;
              final newText = _contentController.text.replaceRange(
                start,
                end,
                result,
              );
              _contentController.text = newText;
              _contentController.selection = TextSelection.collapsed(
                offset: start + result.length,
              );
            } else {
              _contentController.text = result;
            }
            _onContentChanged();
          },
        ),
      ),
    );
  }

  void _addToCalendar() async {
    await _saveNote();

    final titleController = TextEditingController(text: _titleController.text);
    final dateController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    if (!mounted) return;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    showAdaptiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDesktop ? null : Theme.of(context).scaffoldBackgroundColor,
      child: Builder(
        builder: (ctx) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: isDesktop
                    ? (isDark ? const Color(0xFF1A1D21) : Colors.white)
                    : Theme.of(ctx).scaffoldBackgroundColor,
                borderRadius: isDesktop
                    ? BorderRadius.circular(20)
                    : const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isDesktop) ...[
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white24 : Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  const Text(
                    'Add to Calendar',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'Enter event title',
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: ctx,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        selectedDate = date;
                        dateController.text =
                            '${date.day}/${date.month}/${date.year}';
                      }
                    },
                    child: TextField(
                      controller: dateController,
                      enabled: false,
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        hintText: 'Select date',
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (titleController.text.isEmpty) {
                          showErrorSnackBar(ctx, 'Please enter a title');
                          return;
                        }

                        final authService = Provider.of<AuthService>(
                          ctx,
                          listen: false,
                        );
                        final calendarService = CalendarService(authService);

                        await calendarService.createEvent(
                          CalendarEvent(
                            title: titleController.text,
                            date: selectedDate,
                            isAllDay: true,
                            color: _color,
                          ),
                        );

                        if (mounted) {
                          Navigator.pop(ctx);
                          showSuccessSnackBar(context, 'Event added to calendar!');
                        }
                      },
                      child: const Text('Add Event'),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _convertNoteType() {
    if (_noteType == 'text') {
      final lines = _contentController.text
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      setState(() {
        _noteType = 'checklist';
        _checklistItems = lines.isEmpty
            ? [
                ChecklistItem(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                ),
              ]
            : lines
                  .asMap()
                  .entries
                  .map(
                    (e) => ChecklistItem(
                      id: '${DateTime.now().millisecondsSinceEpoch}_${e.key}',
                      text: e.value,
                    ),
                  )
                  .toList();
      });
      _initChecklistControllers();
    } else {
      final text = _checklistItems
          .where((item) => item.text.isNotEmpty)
          .map((item) => item.text)
          .join('\n');
      setState(() {
        _noteType = 'text';
        _contentController.text = text;
      });
    }
    
    // Immediately save and notify parent of the type change
    _saveNote();
    
    showSuccessSnackBar(context, 'Converted to ${_noteType == 'text' ? 'text note' : 'checklist'}');
  }

  /// Unified Share & Collaborate sheet with three options
  void _showShareAndCollaborateSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    showAdaptiveModal(
      context: context,
      backgroundColor: isDesktop ? null : Colors.transparent,
      child: Builder(
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!isDesktop) ...[
                // Drag handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Title
              Row(
                children: [
                  const Icon(Icons.share_outlined, color: AppTheme.primaryColor, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Share & Collaborate',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Option 1: Collaborate (Live)
              _buildShareOption(
                isDark: isDark,
                icon: Icons.people_outline_rounded,
                iconColor: Colors.blue,
                title: 'Collaborate',
                description: 'Invite others to view or edit this note in real time. Changes stay synced.',
                badgeCount: _collaborators.isNotEmpty ? _collaborators.length : null,
                onTap: () {
                  Navigator.pop(ctx);
                  _showCollaboratorsDialog();
                },
              ),

              const SizedBox(height: 12),

              // Option 2: Share a Copy (Snapshot)
              _buildShareOption(
                isDark: isDark,
                icon: Icons.link_rounded,
                iconColor: AppTheme.primaryColor,
                title: 'Share a Copy',
                description: 'Generate a read-only link to a frozen snapshot of this note. No login required to view.',
                onTap: () {
                  Navigator.pop(ctx);
                  _createAndShareSnapshot();
                },
              ),

              const SizedBox(height: 12),

              // Option 3: Copy Text
              _buildShareOption(
                isDark: isDark,
                icon: Icons.content_copy_rounded,
                iconColor: Colors.orange,
                title: 'Copy Text',
                description: 'Copy the note\'s content as plain text to your clipboard.',
                onTap: () {
                  Navigator.pop(ctx);
                  _copyNoteText();
                },
              ),

              const SizedBox(height: 20),

              // FAQ Section
              _buildShareFaq(isDark),

              SizedBox(height: isDesktop ? 0 : MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareOption({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white10 : Colors.grey.shade200,
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        if (badgeCount != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white38 : AppTheme.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              // Chevron
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? Colors.white24 : Colors.grey.shade400,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShareFaq(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200,
          width: 0.5,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Icon(
            Icons.help_outline_rounded,
            size: 18,
            color: isDark ? Colors.white30 : Colors.grey.shade500,
          ),
          title: Text(
            'What\'s the difference?',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
            ),
          ),
          iconColor: isDark ? Colors.white30 : Colors.grey.shade500,
          collapsedIconColor: isDark ? Colors.white30 : Colors.grey.shade500,
          children: [
            _buildFaqItem(
              isDark: isDark,
              question: 'When should I use Collaborate?',
              answer: 'Use Collaborate when you want others to work on the same note with you. '
                  'Changes are synced live — edits by any collaborator update the original note for everyone.',
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              isDark: isDark,
              question: 'What does Share a Copy do?',
              answer: 'It creates a frozen snapshot of your note at this moment and generates a link. '
                  'Anyone with the link can view the copy — no login needed. '
                  'If you edit the note later, the shared copy stays unchanged.',
            ),
            const SizedBox(height: 12),
            _buildFaqItem(
              isDark: isDark,
              question: 'How is Copy Text different?',
              answer: 'Copy Text simply puts your note\'s content on your clipboard as plain text. '
                  'You can then paste it into an email, message, or any app — no link is created.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqItem({
    required bool isDark,
    required String question,
    required String answer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white30 : AppTheme.textMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  /// Create a snapshot and show the share link
  void _createAndShareSnapshot() async {
    if (_noteId == null) {
      await _saveNote();
    }
    if (_noteId == null) {
      if (mounted) {
        showErrorSnackBar(context, 'Please save the note first');
      }
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);

      final token = await notesService.createNoteSnapshot(
        noteId: _noteId!,
        title: _titleController.text,
        content: _contentController.text,
        noteType: _noteType,
        checklistItems: _checklistItems,
        color: _color,
      );

      final origin = kIsWeb ? platform.getLocationOrigin() : 'https://app.inksyncnote.com';
      final baseUrl = '$origin/snapshot';
      final snapshotUrl = '$baseUrl/$token';

      if (mounted) Navigator.pop(context); // Close loading

      // Show link sharing sheet
      _showSnapshotLinkSheet(snapshotUrl);
    } catch (e) {
      if (mounted) Navigator.pop(context); // Close loading
      if (mounted) {
        showErrorSnackBar(context, 'Error creating snapshot: $e');
      }
    }
  }

  /// Show the generated snapshot link with copy and share options
  void _showSnapshotLinkSheet(String url) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    showAdaptiveModal(
      context: context,
      backgroundColor: isDesktop ? null : Colors.transparent,
      isScrollControlled: true,
      child: Builder(
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1D21) : Colors.white,
            borderRadius: isDesktop
                ? BorderRadius.circular(20)
                : const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isDesktop) ...[
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Success icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: AppTheme.primaryColor,
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Snapshot Link Ready',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Anyone with this link can view a read-only copy',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white38 : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 20),

                // Link display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        size: 18,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          url,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: url));
                          showSuccessSnackBar(ctx, 'Link copied!');
                        },
                        icon: const Icon(Icons.copy_rounded, size: 18),
                        label: const Text('Copy Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: isDark ? Colors.white70 : AppTheme.textPrimary,
                          side: BorderSide(
                            color: isDark ? Colors.white24 : Colors.grey.shade300,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final title = _titleController.text.isEmpty
                              ? 'Shared Note'
                              : _titleController.text;
                          Share.share(
                            'Check out "$title" on InkSync!\n\n$url\n\n'
                            'inksyncnote.com is a free cross-platform note-taking app.',
                            subject: title,
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 18),
                        label: const Text('Share Link'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: isDesktop ? 0 : MediaQuery.of(ctx).padding.bottom + 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Copy note text to clipboard
  void _copyNoteText() {
    String textToCopy;
    final title = _titleController.text;

    if (_noteType == 'checklist') {
      final itemsText = _checklistItems.map((item) {
        return '${item.checked ? '☑' : '☐'} ${item.text}';
      }).join('\n');
      textToCopy = title.isNotEmpty ? '$title\n\n$itemsText' : itemsText;
    } else {
      final content = _contentController.text;
      textToCopy = title.isNotEmpty ? '$title\n\n$content' : content;
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    showSuccessSnackBar(context, 'Note text copied to clipboard');
  }

  Future<void> _deleteNote() async {
    // Non-creators can only leave, not delete
    if (!_isCreator) {
      _showCollaboratorsDialog();
      return;
    }

    if (_noteId == null) {
      Navigator.pop(context);
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Move to Trash?'),
        content: const Text('This note will be moved to trash.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.heavyImpact();
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      await notesService.trashNote(_noteId!);
      if (mounted) {
        Navigator.pop(context);
        showSuccessSnackBar(context, 'Note moved to trash');
      }
    }
  }

  void _deleteChecklistItem(int index) {
    setState(() {
      _checklistItems.removeAt(index);
      _checklistFocusNodes[index].dispose();
      _checklistControllers[index].dispose();
      _checklistFocusNodes.removeAt(index);
      _checklistControllers.removeAt(index);
    });
    _onContentChanged();
  }

  void _addChecklistItem(int afterIndex) {
    final newItem = ChecklistItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
    final insertIndex = afterIndex + 1;

    setState(() {
      _checklistItems.insert(insertIndex, newItem);
      _checklistFocusNodes.insert(insertIndex, FocusNode());
      _checklistControllers.insert(insertIndex, TextEditingController());
    });
    _onContentChanged();

    // Focus the new item
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (insertIndex < _checklistFocusNodes.length) {
        _checklistFocusNodes[insertIndex].requestFocus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLocked && !_isUnlocked && widget.note != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'This note is locked',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showUnlockDialog,
                icon: const Icon(Icons.lock_open),
                label: const Text('Unlock'),
              ),
            ],
          ),
        ),
      );
    }

    final isWide = MediaQuery.of(context).size.width > 900;
    final showAppBar = !widget.isEmbedded && !isWide;

    // Theme based note colors
    final backgroundColor = isDark
        ? AppTheme.noteBodyColorsDark[_color] ?? AppTheme.bgPrimaryDark
        : AppTheme.noteHeaderColors[_color] ?? AppTheme.bgPrimary;
    final headerColor = isDark
        ? AppTheme.noteColorsDark[_color] ?? const Color(0xFF2D2D2D)
        : AppTheme.noteColors[_color] ?? const Color(0xFFFAFAFA);

    return WillPopScope(
      onWillPop: () async {
        // Mobile two-step back: first exit edit mode, then close note
        if (_isEditing && !kIsWeb) {
          if (_hasChanges) await _saveNote();
          setState(() {
            _isEditing = false;
            _titleFocusNode.unfocus();
            _contentFocusNode.unfocus();
          });
          return false; // Don't pop — just exited edit mode
        }
        if (_hasChanges) await _saveNote();
        return true;
      },
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: showAppBar

          ? _buildNormalAppBar(headerColor, isDark)
          : null,
      body: SafeArea(
        child: Column(
          children: [
            if (!showAppBar) _buildMinimalistToolbar(isDark),
            // Search bar under header for both mobile and desktop
            if (_showSearch) _buildEmbeddedSearchBar(isDark),
            Expanded(
              child: _noteType == 'text'
                  ? _buildTextEditor()
                  : _buildChecklistEditor(),
            ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildMinimalistToolbar(bool isDark) {
    final toolbarColor = isDark
        ? AppTheme.noteColorsDark[_color] ?? AppTheme.bgPrimaryDark
        : AppTheme.noteColors[_color] ?? AppTheme.bgPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: toolbarColor,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Back button - saves if edited, then closes
          if (!widget.isEmbedded)
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () async {
                if (_hasChanges) {
                  await _saveNote();
                }
                if (mounted) Navigator.pop(context);
              },
            ),
          if (widget.isEmbedded)
            IconButton(
              icon: const Icon(Icons.close_rounded, size: 20),
              tooltip: 'Close note',
              onPressed: () async {
                if (_hasChanges) {
                  await _saveNote();
                }
                // Clear selection to close the note in embedded mode
                if (mounted) {
                  Provider.of<SelectionProvider>(
                    context,
                    listen: false,
                  ).clearSelection();
                }
              },
            ),

          // Note type
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Icon(
                      Icons.push_pin,
                      size: 16,
                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                    ),
                  ),
                Flexible(
                  child: _isEditing
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : Colors.black.withValues(alpha: 0.1),
                            ),
                          ),
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            readOnly: !_isEditing || !_canUserEdit,
                            autofocus: false,
                            contextMenuBuilder: (context, editableTextState) {
                              return AdaptiveTextSelectionToolbar.editableText(
                                editableTextState: editableTextState,
                              );
                            },
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            decoration: InputDecoration(
                              hintText: _noteType == 'checklist' ? 'Checklist Title' : 'Note Title',
                              hintStyle: TextStyle(
                                color: isDark ? Colors.white38 : AppTheme.textMuted,
                              ),
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isDense: true,
                            ),
                          ),
                        )
                      : GestureDetector(
                          onDoubleTap: _canUserEdit ? () {
                            setState(() {
                              _isEditing = true;
                              _showSearch = false;
                            });
                            _titleFocusNode.requestFocus();
                          } : null,
                          child: Text(
                            _titleController.text.isNotEmpty
                                ? _titleController.text
                                : (_noteType == 'checklist' ? 'New Checklist' : 'New Note'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
              ],
            ),
          ),

          // Search in note toggle button
          IconButton(
            icon: Icon(
              _showSearch ? Icons.search_off : Icons.search_rounded,
              color: _showSearch
                  ? AppTheme.primaryColor
                  : (isDark ? Colors.white70 : AppTheme.textSecondary),
              size: 22,
            ),
            tooltip: _showSearch ? 'Close search' : 'Search in note',
            onPressed: () => setState(() => _showSearch = !_showSearch),
          ),

          // Edit toggle button (moved next to menu, acts as save when checking)
          if (!_isEditing)
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
              tooltip: 'Edit note',
              onPressed: _canUserEdit ? () => setState(() {
                _isEditing = true;
                _showSearch = false;
              }) : null,
            )
          else
            IconButton(
              icon: const Icon(
                Icons.check_rounded,
                color: AppTheme.primaryColor,
              ),
              tooltip: 'Done editing',
              onPressed: () async {
                if (_hasChanges) await _saveNote();
                setState(() => _isEditing = false);
              },
            ),

          // AI Assist action (only visible in text notes when editing)
          if (_noteType == 'text' && _isEditing)
            _buildToolbarAction(
              icon: Icons.auto_fix_high,
              tooltip: 'AI Assist',
              onPressed: _showWritingAssist,
              color: AppTheme.primaryColor,
            ),

          // More menu - matching mobile AppBar menu
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_horiz_rounded),
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) async {
              switch (value) {
                case 'pin':
                  HapticFeedback.mediumImpact();
                  setState(() => _isPinned = !_isPinned);
                  _onContentChanged();
                  await _saveNote();
                  break;
                case 'notification_pin':
                  _toggleNotificationPin();
                  break;
                case 'color':
                  _showColorPicker();
                  break;
                case 'tags':
                  _showTagsSheet();
                  break;
                case 'calendar':
                  _addToCalendar();
                  break;
                case 'convert':
                  _convertNoteType();
                  break;
                case 'share_collaborate':
                  _showShareAndCollaborateSheet();
                  break;
                case 'lock':
                  _showLockDialog();
                  break;
                case 'delete':
                  _deleteNote();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'pin',
                child: Row(
                  children: [
                    Icon(
                      _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(_isPinned ? 'Unpin' : 'Pin to Top'),
                  ],
                ),
              ),
              if (!kIsWeb)
                PopupMenuItem(
                  value: 'notification_pin',
                  child: Row(
                    children: [
                      Icon(
                        _isPinnedToNotifications
                            ? Icons.notifications_active
                            : Icons.notifications_active_outlined,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isPinnedToNotifications
                            ? 'Unpin Notification'
                            : 'Pin to Notification Bar',
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'color',
                child: Row(
                  children: [
                    Icon(Icons.palette_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Change Color'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'tags',
                child: Row(
                  children: [
                    Icon(Icons.label_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Manage Tags'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'calendar',
                child: Row(
                  children: [
                    Icon(Icons.calendar_today_outlined, size: 20),
                    SizedBox(width: 12),
                    Text('Add to Calendar'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'convert',
                child: Row(
                  children: [
                    Icon(
                      _noteType == 'text' ? Icons.checklist : Icons.notes,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _noteType == 'text'
                          ? 'Convert to Checklist'
                          : 'Convert to Text',
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share_collaborate',
                child: Row(
                  children: [
                    const Icon(Icons.share_outlined, size: 20),
                    const SizedBox(width: 12),
                    const Text('Share & Collaborate'),
                    if (_collaborators.isNotEmpty) ...[
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_collaborators.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lock',
                child: Row(
                  children: [
                    Icon(_isLocked ? Icons.lock : Icons.lock_outline, size: 20),
                    const SizedBox(width: 12),
                    Text(_isLocked ? 'Remove Lock' : 'Lock Note'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(
                      _isCreator ? Icons.delete_outline : Icons.exit_to_app,
                      color: Colors.red,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isCreator ? 'Delete' : 'Leave',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbarAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 20, color: color),
        onPressed: onPressed,
        splashRadius: 24,
      ),
    );
  }

  Widget _buildEmbeddedSearchBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary,
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.search_rounded,
                    size: 16,
                    color: Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      autofocus: true,
                      style: const TextStyle(fontSize: 14),
                      decoration: const InputDecoration(
                        hintText: 'Search in note...',
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () => _searchController.clear(),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: Colors.grey,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_searchMatches.isNotEmpty) ...[
            const SizedBox(width: 8),
            Text(
              '${_currentMatchIndex + 1}/${_searchMatches.length}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_up_rounded, size: 20),
              onPressed: _prevMatch,
            ),
            IconButton(
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
              onPressed: _nextMatch,
            ),
          ],
          TextButton(
            onPressed: () => setState(() {
              _showSearch = false;
              _searchController.clear();
            }),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildNormalAppBar(Color headerColor, bool isDark) {
    return AppBar(
      backgroundColor: headerColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
        onPressed: () async {
          // Mobile two-step back: first exit edit mode, then close note
          if (_isEditing && !kIsWeb) {
            if (_hasChanges) await _saveNote();
            setState(() {
              _isEditing = false;
              _titleFocusNode.unfocus();
              _contentFocusNode.unfocus();
            });
            return; // Don't pop — just exited edit mode
          }
          final navigator = Navigator.of(context);
          if (_hasChanges) await _saveNote();
          if (mounted) navigator.pop();
        },
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isPinned)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Icon(
                Icons.push_pin,
                size: 16,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
          Flexible(
            child: _isEditing
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.15)
                            : Colors.black.withValues(alpha: 0.1),
                      ),
                    ),
                    child: TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      readOnly: !_isEditing || !_canUserEdit,
                      autofocus: false,
                      contextMenuBuilder: (context, editableTextState) {
                        return AdaptiveTextSelectionToolbar.editableText(
                          editableTextState: editableTextState,
                        );
                      },
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                      decoration: InputDecoration(
                        hintText: _noteType == 'checklist' ? 'Checklist Title' : 'Note Title',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.white38 : AppTheme.textMuted,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                    ),
                  )
                : GestureDetector(
                    onDoubleTap: _canUserEdit ? () {
                      setState(() {
                        _isEditing = true;
                        _showSearch = false;
                      });
                      _titleFocusNode.requestFocus();
                    } : null,
                    child: Text(
                      _titleController.text.isNotEmpty
                          ? _titleController.text
                          : (_noteType == 'checklist' ? 'New Checklist' : 'New Note'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
          ),
        ],
      ),
      actions: [
        // Search in note toggle button
        IconButton(
          icon: Icon(
            _showSearch ? Icons.search_off : Icons.search_rounded,
            color: _showSearch
                ? AppTheme.primaryColor
                : (isDark ? Colors.white70 : AppTheme.textSecondary),
            size: 22,
          ),
          tooltip: _showSearch ? 'Close search' : 'Search in note',
          onPressed: () => setState(() => _showSearch = !_showSearch),
        ),
        // Edit toggle button
        if (!_isEditing)
          IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
            tooltip: 'Edit note',
            onPressed: _canUserEdit ? () => setState(() {
              _isEditing = true;
              _showSearch = false;
            }) : null,
          )
        else
          IconButton(
            icon: const Icon(
              Icons.check_rounded,
              color: AppTheme.primaryColor,
            ),
            tooltip: 'Done editing',
            onPressed: () async {
              if (_hasChanges) await _saveNote();
              setState(() => _isEditing = false);
            },
          ),
        // AI Assist button (text notes only, edit mode only)
        if (_noteType == 'text' && _isEditing)
          IconButton(
            icon: const Icon(Icons.auto_fix_high, color: AppTheme.primaryColor),
            tooltip: 'AI Assist',
            onPressed: _showWritingAssist,
          ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) async {
            switch (value) {
              case 'pin':
                HapticFeedback.mediumImpact();
                setState(() => _isPinned = !_isPinned);
                _onContentChanged();
                await _saveNote();
                break;
              case 'notification_pin':
                _toggleNotificationPin();
                break;
              case 'color':
                _showColorPicker();
                break;
              case 'tags':
                _showTagsSheet();
                break;
              case 'calendar':
                _addToCalendar();
                break;
              case 'convert':
                _convertNoteType();
                break;
              case 'share_collaborate':
                _showShareAndCollaborateSheet();
                break;
              case 'lock':
                _showLockDialog();
                break;
              case 'delete':
                _deleteNote();
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'pin',
              child: Row(
                children: [
                  Icon(
                    _isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(_isPinned ? 'Unpin' : 'Pin to Top'),
                ],
              ),
            ),
            if (!kIsWeb)
              PopupMenuItem(
                value: 'notification_pin',
                child: Row(
                  children: [
                    Icon(
                      _isPinnedToNotifications
                          ? Icons.notifications_active
                          : Icons.notifications_active_outlined,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _isPinnedToNotifications
                          ? 'Unpin Notification'
                          : 'Pin to Notification Bar',
                    ),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'color',
              child: Row(
                children: [
                  Icon(Icons.palette_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Change Color'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'tags',
              child: Row(
                children: [
                  Icon(Icons.label_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Manage Tags'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'calendar',
              child: Row(
                children: [
                  Icon(Icons.calendar_today_outlined, size: 20),
                  SizedBox(width: 12),
                  Text('Add to Calendar'),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'convert',
              child: Row(
                children: [
                  Icon(
                    _noteType == 'text' ? Icons.checklist : Icons.notes,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _noteType == 'text'
                        ? 'Convert to Checklist'
                        : 'Convert to Text',
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'share_collaborate',
              child: Row(
                children: [
                  const Icon(Icons.share_outlined, size: 20),
                  const SizedBox(width: 12),
                  const Text('Share & Collaborate'),
                  if (_collaborators.isNotEmpty) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_collaborators.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuItem(
              value: 'lock',
              child: Row(
                children: [
                  Icon(_isLocked ? Icons.lock : Icons.lock_outline, size: 20),
                  const SizedBox(width: 12),
                  Text(_isLocked ? 'Remove Lock' : 'Lock Note'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(
                    _isCreator ? Icons.delete_outline : Icons.exit_to_app,
                    color: Colors.red,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isCreator ? 'Delete' : 'Leave',
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildSearchAppBar(Color headerColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradientColors = isDark
        ? [
            headerColor.withValues(alpha: 0.8),
            headerColor.withValues(alpha: 0.4),
          ]
        : [headerColor, headerColor.withValues(alpha: 0.7)];

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 56,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
      ),
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          size: 22,
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
        onPressed: () {
          setState(() {
            _showSearch = false;
            _searchController.clear();
            _searchMatches = [];
            _currentMatchIndex = -1;
            // Clear any selection to prevent AI assist from using selected text
            _contentController.selection = TextSelection.collapsed(
              offset: _contentController.text.length,
            );
          });
        },
      ),
      titleSpacing: 0,
      title: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white30 : Colors.black26,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.search,
              size: 16,
              color: isDark ? Colors.white54 : AppTheme.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : AppTheme.textMuted,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  setState(() {
                    _searchMatches = [];
                    _currentMatchIndex = -1;
                  });
                },
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: isDark ? Colors.white38 : AppTheme.textMuted,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (_searchMatches.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${_currentMatchIndex + 1}/${_searchMatches.length}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_up,
              size: 20,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
            onPressed: _prevMatch,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            icon: Icon(
              Icons.keyboard_arrow_down,
              size: 20,
              color: isDark ? Colors.white70 : AppTheme.textPrimary,
            ),
            onPressed: _nextMatch,
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 4),
        ],
      ],
    );
  }

  Widget _buildMetadataAndTags(bool isDark) {
    if (widget.note?.updatedDate == null && _collaborators.isEmpty && _tags.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Last Edit Date
        if (widget.note?.updatedDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Last edited: ${_formatDate(widget.note!.updatedDate!)}',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white38 : AppTheme.textMuted,
              ),
            ),
          ),

        // 2. Collaborators Section
        if (_collaborators.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.group_outlined,
                      size: 14,
                      color: isDark ? Colors.white54 : AppTheme.textMuted,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Collaborators:',
                      style: TextStyle(
                        fontSize: 11, // Reduced text size
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white54 : AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (_ownerEmail != null)
                      _buildUserBadge(
                        email: _ownerEmail!,
                        role: 'Owner',
                        isDark: isDark,
                        color: Colors.blue,
                      ),
                    ..._collaborators.map(
                      (c) => _buildUserBadge(
                        email: c.email,
                        role: c.canEdit ? 'Editor' : 'Viewer',
                        isDark: isDark,
                        color: c.accepted ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

        // 3. Tags Section
        if (_tags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: _tags.map((tag) => GestureDetector(
                onTap: _isEditing ? _showTagsSheet : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isDark 
                        ? AppTheme.primaryColor.withValues(alpha: 0.15) 
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark 
                          ? AppTheme.primaryColor.withValues(alpha: 0.3) 
                          : AppTheme.primaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark 
                          ? AppTheme.primaryColor.withValues(alpha: 0.9) 
                          : AppTheme.primaryColor,
                    ),
                  ),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildTextEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double fontSize = 16.0;
    const double titleFontSize = 18.0;
    const double lineHeight = 28.0;
    
    final textStyle = TextStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      fontFamily: 'Inter',
      color: isDark ? Colors.white : AppTheme.textPrimary,
      leadingDistribution: TextLeadingDistribution.even,
    );
    
    final strutStyle = const StrutStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      forceStrutHeight: true,
      leadingDistribution: TextLeadingDistribution.even,
    );
    
    final lineColor = isDark ? Colors.white12 : const Color(0xFFE5EAF0);
    final separatorColor = isDark ? Colors.white24 : Colors.black;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          controller: _textScrollController,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                  _buildViewOnlyBanner(),
                  _buildMetadataAndTags(isDark),
                  // Content area (body)
                  GestureDetector(
                    behavior: HitTestBehavior.deferToChild,
                    onTap: () {
                      if (!_canUserEdit || !_isEditing) return;
                      // Already in edit mode — if body doesn't have focus,
                      // switch focus to body and place cursor at end of text
                      if (!_contentFocusNode.hasFocus) {
                        _contentFocusNode.requestFocus();
                        Future.delayed(const Duration(milliseconds: 50), () {
                          if (mounted) {
                            _contentController.selection = TextSelection.collapsed(
                              offset: _contentController.text.length,
                            );
                          }
                        });
                      }
                    },
                    child: Container(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: LinedPaperPainter(
                              lineColor: lineColor,
                              lineHeight: lineHeight,
                              topPadding: -5.0,
                            ),
                          ),
                        ),
                  _showSearch && _searchMatches.isNotEmpty
                      ? Listener(
                          onPointerDown: (event) {
                            if (_isEditing || !_canUserEdit) return;
                            final now = DateTime.now().millisecondsSinceEpoch;
                            if (now - _lastContentTapTime < 300) {
                              final currentSelection = _contentController.selection;
                              setState(() {
                                _isEditing = true;
                                _showSearch = false;
                              });
                              _contentFocusNode.requestFocus();
                              if (currentSelection.isValid) {
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) {
                                    _contentController.selection = currentSelection;
                                  }
                                });
                              }
                            }
                            _lastContentTapTime = now;
                          },
                          child: _buildHighlightedContent(isDark),
                        )
                      : Listener(
                          onPointerDown: (event) {
                            if (_isEditing || !_canUserEdit) return;
                            final now = DateTime.now().millisecondsSinceEpoch;
                            if (now - _lastContentTapTime < 300) {
                              final currentSelection = _contentController.selection;
                              setState(() {
                                _isEditing = true;
                                _showSearch = false;
                              });
                              _contentFocusNode.requestFocus();
                              if (currentSelection.isValid) {
                                Future.delayed(const Duration(milliseconds: 50), () {
                                  if (mounted) {
                                    _contentController.selection = currentSelection;
                                  }
                                });
                              }
                            }
                            _lastContentTapTime = now;
                          },
                          child: TextField(
                            controller: _contentController,
                            focusNode: _contentFocusNode,
                            readOnly: !_isEditing || !_canUserEdit,
                            autofocus: _isEditing && widget.note == null,
                            contextMenuBuilder: (context, editableTextState) {
                              return AdaptiveTextSelectionToolbar.editableText(
                                editableTextState: editableTextState,
                              );
                            },
                            style: textStyle,
                            strutStyle: strutStyle,
                            decoration: InputDecoration(
                              hintText: _isEditing ? 'Start writing...' : '',
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                              isCollapsed: true, // Absolutely zero internal padding
                            ),
                            maxLines: null,
                            textAlignVertical: TextAlignVertical.top,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ),
                ],
              ),
        );
      },
    );
  }

  Widget _buildChecklistEditor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const double lineHeight = 48.0; // Height per checklist item row
    final lineColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE5EAF0);

    return Stack(
      children: [
        const SizedBox.shrink(),
        // Checklist content with title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildViewOnlyBanner(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _buildMetadataAndTags(isDark),
            ),
            // Checklist items
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _checklistItems.length + 1,
                buildDefaultDragHandles: false,
                proxyDecorator: (child, index, animation) {
                  return Material(
                    color: Colors.transparent,
                    elevation: 0,
                    child: child,
                  );
                },
                onReorderStart: (index) {
                  HapticFeedback.lightImpact();
                },
                onReorder: (oldIndex, newIndex) {
                  if (oldIndex >= _checklistItems.length ||
                      newIndex > _checklistItems.length) {
                    return;
                  }
                  HapticFeedback.mediumImpact();
                  setState(() {
                    if (newIndex > oldIndex) newIndex--;
                    final item = _checklistItems.removeAt(oldIndex);
                    _checklistItems.insert(newIndex, item);

                    final node = _checklistFocusNodes.removeAt(oldIndex);
                    _checklistFocusNodes.insert(newIndex, node);

                    final controller = _checklistControllers.removeAt(oldIndex);
                    _checklistControllers.insert(newIndex, controller);
                  });
                  _onContentChanged();
                },
                itemBuilder: (context, index) {
                  if (index == _checklistItems.length) {
                    // Add item button - left aligned, filled
                    return Material(
                      key: const ValueKey('add_item'),
                      color: Colors.transparent,
                      child: Container(
                        height: lineHeight,
                        alignment: Alignment.centerLeft,
                        child: _canUserEdit ? ElevatedButton.icon(
                          onPressed: () =>
                              _addChecklistItem(_checklistItems.length - 1),
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add item'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ) : null,
                      ),
                    );
                  }

                  final item = _checklistItems[index];
                  return Material(
                    key: ValueKey(item.id),
                    color: Colors.transparent,
                    child: SizedBox(
                      height: lineHeight,
                      child: Row(
                        children: [
                          // Drag handle on left
                          if (_canUserEdit) ReorderableDelayedDragStartListener(
                            index: index,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Icon(
                                Icons.drag_indicator,
                                color: AppTheme.textMuted,
                                size: 20,
                              ),
                            ),
                          ),
                          // Checkbox
                          Checkbox(
                            value: item.checked,
                            onChanged: _canUserEdit ? (value) {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _checklistItems[index] = item.copyWith(
                                  checked: value ?? false,
                                );
                              });
                              _onContentChanged();
                            } : null,
                            activeColor: AppTheme.primaryColor,
                            fillColor: WidgetStateProperty.resolveWith((
                              states,
                            ) {
                              if (states.contains(WidgetState.selected)) {
                                return AppTheme.primaryColor;
                              }
                              return Colors.transparent;
                            }),
                            side: BorderSide(
                              color: AppTheme.textMuted,
                              width: 2,
                            ),
                          ),
                          // Text field
                          Expanded(
                            child: Theme(
                              data: Theme.of(context).copyWith(
                                inputDecorationTheme:
                                    const InputDecorationTheme(filled: false),
                              ),
                              child: TextField(
                                controller: _checklistControllers[index],
                                focusNode: _checklistFocusNodes[index],
                                readOnly: !_canUserEdit,
                                contextMenuBuilder: (context, editableTextState) {
                                  return AdaptiveTextSelectionToolbar.editableText(
                                    editableTextState: editableTextState,
                                  );
                                },
                                decoration: const InputDecoration(
                                  hintText: 'List item',
                                  border: InputBorder.none,
                                  filled: false,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                ),
                                style: TextStyle(
                                  decoration: item.checked
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: item.checked
                                      ? AppTheme.textMuted
                                      : null,
                                ),
                                onChanged: (value) {
                                  _checklistItems[index] = item.copyWith(
                                    text: value,
                                  );
                                  _onContentChanged();
                                },
                                onSubmitted: (_) => _addChecklistItem(index),
                                textInputAction: TextInputAction.next,
                              ),
                            ),
                          ),
                          // Delete button - only show for completed items
                          if (item.checked)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () => _deleteChecklistItem(index),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUserBadge({
    required String email,
    required String role,
    required bool isDark,
    required MaterialColor color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            email,
            style: TextStyle(
              fontSize: 10, // Smaller font for neatness
              fontWeight: FontWeight.w500,
              color: isDark ? color.shade300 : color.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              role,
              style: TextStyle(
                fontSize: 8, // Smaller role text
                fontWeight: FontWeight.bold,
                color: isDark ? color.shade200 : color.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lined paper painter for notepad effect
class LinedPaperPainter extends CustomPainter {
  final Color lineColor;
  final double lineHeight;
  final double topPadding;

  LinedPaperPainter({
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

    // Draw lines starting from the first text baseline
    // First line appears below the first line of text
    double y = topPadding + lineHeight;

    while (y < size.height) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      y += lineHeight;
    }
  }

  @override
  bool shouldRepaint(covariant LinedPaperPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.lineHeight != lineHeight ||
        oldDelegate.topPadding != topPadding;
  }
}

/// AI Writing Assist Sheet with editable suggestions
class AIWritingAssistSheet extends StatefulWidget {
  final String text;
  final bool hasSelection;
  final Function(String) onInsert;

  const AIWritingAssistSheet({
    super.key,
    required this.text,
    required this.hasSelection,
    required this.onInsert,
  });

  @override
  State<AIWritingAssistSheet> createState() => _AIWritingAssistSheetState();
}

class _AIWritingAssistSheetState extends State<AIWritingAssistSheet> {
  String? _selectedTone;
  final TextEditingController _resultController = TextEditingController();
  bool _isProcessing = false;
  String? _error;

  Future<void> _processText(String tone) async {
    setState(() {
      _selectedTone = tone;
      _isProcessing = true;
      _error = null;
    });

    try {
      final geminiService = Provider.of<GeminiService>(context, listen: false);
      final result = await geminiService.processText(widget.text, tone);
      


      setState(() {
        _resultController.text = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isProcessing = false;
      });
    }
  }

  @override
  void dispose() {
    _resultController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width > 800;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: isDesktop
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      height: isDesktop 
          ? MediaQuery.of(context).size.height * 0.7 
          : MediaQuery.of(context).size.height * 0.75,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isDesktop) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primaryColor.withValues(alpha: 0.2),
                      AppTheme.primaryColor.withValues(alpha: 0.05),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  ),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                'AI Writing Assist',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.1) : Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.blue.withValues(alpha: 0.2) : Colors.blue.shade100,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: isDark ? Colors.blue.shade300 : Colors.blue.shade700,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    "I'll magically rewrite just the text you've selected.",
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.blue.shade200 : Colors.blue.shade800,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: GeminiService.tones.map((tone) {
              final isSelected = _selectedTone == tone['id'];
              return ChoiceChip(
                label: Text('${tone['icon']} ${tone['label']}'),
                selected: isSelected,
                onSelected: (_) => _processText(tone['id']!),
                selectedColor: isDark
                    ? AppTheme.primaryColor.withValues(alpha: 0.25)
                    : AppTheme.primaryColor.withValues(alpha: 0.15),
                backgroundColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                labelStyle: TextStyle(
                  color: isSelected
                      ? AppTheme.primaryColor
                      : (isDark ? Colors.white70 : Colors.black87),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.5)
                        : Colors.transparent,
                  ),
                ),
                showCheckmark: false,
                elevation: 0,
                pressElevation: 0,
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade200,
                ),
              ),
              child: _isProcessing
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppTheme.primaryColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Enhancing your text...',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white54 : AppTheme.textMuted,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'This may take a few seconds',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white30 : Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Colors.red.shade400,
                            size: 48,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Error processing text',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ],
                      ),
                    )
                  : _resultController.text.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.auto_awesome_outlined,
                            size: 48,
                            color: isDark
                                ? Colors.white24
                                : Colors.grey.shade300,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Select a tone above to magically transform your text',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark
                                  ? Colors.white38
                                  : AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    )
                  : SingleChildScrollView(
                      child: TextField(
                        controller: _resultController,
                        maxLines: null,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.6,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Edit the suggestion...',
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 16),

          if (_resultController.text.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _selectedTone != null
                        ? () => _processText(_selectedTone!)
                        : null,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Rerun'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      widget.onInsert(_resultController.text);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text(
                      'Replace Selection',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
