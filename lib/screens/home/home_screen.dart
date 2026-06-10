import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/notes_service.dart';
import '../../services/tag_service.dart';
import '../../providers/settings_provider.dart';
import '../../config/theme.dart';
import '../../widgets/note_card.dart';
import '../../widgets/invite_banner.dart';
import '../note_edit/note_edit_screen.dart';
import '../../providers/selection_provider.dart';
import '../../utils/ui_helper.dart';
import '../../services/local_database_service.dart';

/// Modern HomeScreen with simplified header - menu in bottom nav
class HomeScreen extends StatefulWidget {
  final String? noteTypeFilter; // 'text', 'checklist', or null for all
  final bool isSyncing;

  const HomeScreen({super.key, this.noteTypeFilter, this.isSyncing = false});

  @override
  HomeScreenState createState() => HomeScreenState();
}


class HomeScreenState extends State<HomeScreen> {
  /// Public method to refresh data from external callers
  Future<void> refreshData() async {
    debugPrint('HomeScreen refreshData called for ${widget.noteTypeFilter}');
    await _loadData();
  }

  // ── Global Search State ──
  String _globalSearchQuery = '';
  final TextEditingController _globalSearchController = TextEditingController();
  final FocusNode _globalSearchFocusNode = FocusNode();
  bool _isGlobalSearchActive = false;
  List<Note> _allNotesCache = []; // Cache of ALL notes for global search

  /// Called from MainNavigation to toggle the inline search bar
  void activateSearch() {
    setState(() => _isGlobalSearchActive = true);
    _loadAllNotesForSearch();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _globalSearchFocusNode.requestFocus();
    });
  }

  /// Dismiss search and revert to preset filters
  void deactivateSearch() {
    setState(() {
      _isGlobalSearchActive = false;
      _globalSearchQuery = '';
      _globalSearchController.clear();
    });
  }

  bool get isSearchActive => _isGlobalSearchActive;

  /// Load ALL notes (active + trashed) for global search
  Future<void> _loadAllNotesForSearch() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final active = await notesService.getActiveNotes();
      final trashed = await notesService.getTrashedNotes();
      _allNotesCache = [...active, ...trashed];
    } catch (e) {
      _allNotesCache = List.from(_notes);
    }
  }

  List<Note> _notes = [];
  List<Tag> _tags = [];
  List<Map<String, dynamic>> _pendingInvites = [];
  String? _selectedTagName; // null means "All"
  String? _highlightedNoteId;
  bool _isLoading = true;
  bool _hasLoadedOnce = false;
  bool _hasUnsyncedChanges = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSettings();
      _loadData();
      _loadInvites();
    });
  }

  Future<void> _loadSettings() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(
        context,
        listen: false,
      );
      await settingsProvider.loadSettings(authService);
    } catch (e) {
      // Use defaults
    }
  }

  /// Check if the fetched notes differ from the current in-memory list.
  /// Compares count, IDs, and updated timestamps to detect real changes.
  bool _hasNotesChanged(List<Note> newNotes) {
    if (newNotes.length != _notes.length) return true;

    // Build a map of id -> updatedDate for fast lookup
    final oldMap = <String, DateTime?>{};
    for (final note in _notes) {
      if (note.id != null) oldMap[note.id!] = note.updatedDate;
    }

    for (final note in newNotes) {
      if (note.id == null) return true;
      if (!oldMap.containsKey(note.id)) return true;
      if (oldMap[note.id] != note.updatedDate) return true;
    }

    return false;
  }

  /// Check if the fetched tags differ from the current in-memory list.
  bool _hasTagsChanged(List<Tag> newTags) {
    if (newTags.length != _tags.length) return true;
    for (int i = 0; i < newTags.length; i++) {
      if (newTags[i].name != _tags[i].name) return true;
      if (newTags[i].id != _tags[i].id) return true;
    }
    return false;
  }

  Future<void> _loadData() async {
    // Only show the loading spinner on the very first load
    if (!_hasLoadedOnce) {
      setState(() => _isLoading = true);
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final tagService = TagService(authService);

      final notes = await notesService.getActiveNotes();

      List<Tag> tags = [];
      try {
        if (widget.noteTypeFilter != null) {
          tags = await tagService.getTagsByType(
            widget.noteTypeFilter!,
          );
        } else {
          tags = await tagService.getTags();
        }
      } catch (tagError) {
        debugPrint('Error loading tags: $tagError');
      }

      // Auto-repair: create tag definitions for tags used in notes but missing
      // from the definitions table (e.g. after data wipe + re-sync).
      try {
        final existingTagNames = tags.map((t) => t.name.toLowerCase()).toSet();
        final missingTagNames = <String>{};
        final noteTypeForTags = widget.noteTypeFilter ?? 'text';

        for (final note in notes) {
          // Only check notes matching the current type filter
          if (widget.noteTypeFilter != null && note.type != widget.noteTypeFilter) continue;
          for (final tagName in note.tags) {
            if (tagName.isNotEmpty && !existingTagNames.contains(tagName.toLowerCase())) {
              missingTagNames.add(tagName);
            }
          }
        }

        if (missingTagNames.isNotEmpty) {
          debugPrint('Auto-repairing ${missingTagNames.length} missing tag definitions: $missingTagNames');
          for (final tagName in missingTagNames) {
            await tagService.createTag(tagName, type: noteTypeForTags);
          }
          // Re-fetch tags to include the newly created definitions
          if (widget.noteTypeFilter != null) {
            tags = await tagService.getTagsByType(widget.noteTypeFilter!);
          } else {
            tags = await tagService.getTags();
          }
        }
      } catch (e) {
        debugPrint('Error auto-repairing tags: $e');
      }

      bool hasPending = false;
      if (!kIsWeb) {
        final pendingNotes = await LocalDatabaseService.instance.getPendingNotes();
        final pendingTags = await LocalDatabaseService.instance.getPendingTags();
        hasPending = pendingNotes.isNotEmpty || pendingTags.isNotEmpty;
      }

      if (!mounted) return;

      // On first load, always apply. On subsequent loads, only if data changed or sync state changed.
      if (!_hasLoadedOnce || _hasNotesChanged(notes) || _hasTagsChanged(tags) || _hasUnsyncedChanges != hasPending) {
        setState(() {
          _notes = notes;
          _tags = tags;
          _hasUnsyncedChanges = hasPending;
          _sortNotes();
          _isLoading = false;
          _hasLoadedOnce = true;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading data: $e\n$stackTrace');
      if (!_hasLoadedOnce) {
        setState(() => _isLoading = false);
      }
      if (mounted) {
        showErrorSnackBar(context, 'Error loading notes: $e');
      }
    }
  }

  Future<void> _loadInvites() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final invites = await notesService.getPendingInvites();
      setState(() => _pendingInvites = invites);
    } catch (e) {
      debugPrint('Error loading invites: $e');
    }
  }

  Future<void> _handleAcceptInvite(String inviteId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      await notesService.acceptInvite(inviteId);

      if (mounted) {
        showSuccessSnackBar(context, 'Invite accepted! Note added to your collection.');
      }

      _loadInvites();
      _loadData();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error accepting invite: $e');
      }
    }
  }

  void _handleDismissInvite(String inviteId) {
    setState(() {
      _pendingInvites.removeWhere((invite) => invite['id'] == inviteId);
    });
  }

  Future<void> _handleRejectInvite(String inviteId) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      await notesService.rejectInvite(inviteId);

      if (mounted) {
        showSuccessSnackBar(context, 'Invite declined');
      }

      _loadInvites();
    } catch (e) {
      if (mounted) {
        showErrorSnackBar(context, 'Error declining invite: $e');
      }
    }
  }

  List<Note> get _filteredNotes {
    // ── Global Search Mode: bypass all type/tag filters ──
    if (_isGlobalSearchActive && _globalSearchQuery.isNotEmpty) {
      final lowerQuery = _globalSearchQuery.toLowerCase();
      return _allNotesCache.where((note) {
        if (note.title.toLowerCase().contains(lowerQuery)) return true;
        if (note.tags.any(
          (tag) => tag.toLowerCase().contains(lowerQuery),
        )) return true;
        if (!note.isLocked) {
          if (note.content.toLowerCase().contains(lowerQuery)) return true;
          if (note.checklistItems.any(
            (item) => item.text.toLowerCase().contains(lowerQuery),
          )) return true;
        }
        return false;
      }).toList();
    }

    var notes = _notes;

    // Filter by note type if specified
    if (widget.noteTypeFilter != null) {
      notes = notes.where((n) => n.type == widget.noteTypeFilter).toList();
    }

    // Filter by tag if selected
    if (_selectedTagName != null) {
      debugPrint('Filtering by tag: $_selectedTagName');
      debugPrint('Notes before filter: ${notes.length}');
      for (var n in notes) {
        debugPrint('Note "${n.title}" tags: ${n.tags}');
      }
      notes = notes.where((n) => n.tags.map((t) => t.toLowerCase()).contains(_selectedTagName!.toLowerCase())).toList();
      debugPrint('Notes after filter: ${notes.length}');
    }

    return notes;
  }

  void _sortNotes() {
    final settingsProvider = Provider.of<SettingsProvider>(
      context,
      listen: false,
    );
    final sortBy = settingsProvider.sortBy;

    _notes.sort((a, b) {
      // Pinned notes always first
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;

      switch (sortBy) {
        case 'created':
          return (b.createdDate ?? DateTime.now()).compareTo(
            a.createdDate ?? DateTime.now(),
          );
        case 'alphabetical':
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case 'color':
          return a.color.compareTo(b.color);
        case 'reminder':
          final aReminder = a.reminderAt ?? DateTime(2100);
          final bReminder = b.reminderAt ?? DateTime(2100);
          return aReminder.compareTo(bReminder);
        case 'modified':
        default:
          return (b.updatedDate ?? DateTime.now()).compareTo(
            a.updatedDate ?? DateTime.now(),
          );
      }
    });
  }

  void _openNote(Note note) {
    final selectionProvider = Provider.of<SelectionProvider>(
      context,
      listen: false,
    );
    final isWide = MediaQuery.of(context).size.width > 900;
    final searchQuery = _isGlobalSearchActive ? _globalSearchQuery : null;

    if (isWide) {
      // Pass search query via SelectionProvider for the embedded editor
      selectionProvider.selectNote(note, searchQuery: searchQuery);
    } else {
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => NoteEditScreen(
            note: note,
            initialSearchQuery: searchQuery,
          ),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      ).then((_) => _loadData());
    }
  }

  void _showNoteContextMenu(Note note) {
    HapticFeedback.mediumImpact();
    setState(() {
      _highlightedNoteId = note.id;
    });
    final isDesktop = MediaQuery.of(context).size.width > 800;
    final authService = Provider.of<AuthService>(context, listen: false);
    final isCreator = note.createdBy == null || note.createdBy!.isEmpty || note.createdBy == authService.currentUserId;

    showAdaptiveModal(
      context: context,
      backgroundColor: isDesktop ? null : Colors.transparent,
      child: Builder(
        builder: (ctx) => _NoteContextMenu(
          note: note,
          isCreator: isCreator,
          onPin: () {
            Navigator.pop(ctx);
            _togglePin(note);
          },
          onDelete: () {
            Navigator.pop(ctx);
            if (isCreator) {
              _deleteNote(note);
            } else {
              _leaveNote(note);
            }
          },
          onOpen: () {
            Navigator.pop(ctx);
            _openNote(note);
          },
          onMore: () {
            Navigator.pop(ctx);
            _openNote(note);
          },
        ),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _highlightedNoteId = null;
        });
      }
    });
  }

  Future<void> _togglePin(Note note) async {
    HapticFeedback.mediumImpact();
    final authService = Provider.of<AuthService>(context, listen: false);
    final notesService = NotesService(authService);
    await notesService.updateNote(note.id!, {'isPinned': !note.isPinned});
    _loadData();
  }

  Future<void> _deleteNote(Note note) async {
    HapticFeedback.heavyImpact();
    final authService = Provider.of<AuthService>(context, listen: false);
    final notesService = NotesService(authService);
    await notesService.trashNote(note.id!);
    _loadData();
    if (mounted) {
      showSuccessSnackBar(context, 'Note moved to trash');
    }
  }

  Future<void> _leaveNote(Note note) async {
    HapticFeedback.mediumImpact();
    // TODO: Implement leave collaboration via API
    // For now, show a message directing to the note's collaborator settings
    if (mounted) {
      showSuccessSnackBar(context, 'Open the note and use the menu to leave this collaboration');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isWide = MediaQuery.of(context).size.width > 900;

    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Scaffold(
          backgroundColor: isWide ? Colors.transparent : null,
          body: SafeArea(
            child: Column(
              children: [
                // Simplified Header - just logo
                _buildHeader(isDark),

                // Inline Global Search Bar
                if (_isGlobalSearchActive) _buildGlobalSearchBar(isDark),

                // Pending invites banner (hide during search)
                if (!_isGlobalSearchActive)
                  InviteBanner(
                    invites: _pendingInvites,
                    onAccept: _handleAcceptInvite,
                    onReject: _handleRejectInvite,
                    onDismiss: _handleDismissInvite,
                  ),

                // Tag tabs - hide during search
                if (!_isGlobalSearchActive) _buildTagTabs(isDark),

                if (isWide && !_isGlobalSearchActive) const Divider(height: 1, thickness: 0.5),

                // Notes List
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: _isLoading
                        ? _buildLoading()
                        : _filteredNotes.isEmpty
                        ? _buildEmptyState(isDark)
                        : RefreshIndicator(
                            onRefresh: () async {
                              HapticFeedback.lightImpact();
                              await _loadData();
                            },
                            color: AppTheme.primaryColor,
                            child: _buildNotesView(settingsProvider.viewMode),
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isDark) {
    final isWide = MediaQuery.of(context).size.width > 900;
    final headerTitle = widget.noteTypeFilter == 'checklist'
        ? 'Checklists'
        : 'Notes';
    final authService = Provider.of<AuthService>(context, listen: false);

    // Build header with InkSync branding + section name
    return Container(
      padding: EdgeInsets.fromLTRB(
        isWide ? 20 : 16,
        isWide ? 16 : 12,
        isWide ? 20 : 16,
        isWide ? 12 : 8,
      ),
      child: Row(
        children: [
          // Gradient InkSync Logo
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [
                Color(0xFF1E88E5), // Blue
                Color(0xFF10D98C), // Green
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: Image.asset(
              'assets/images/logo_transparent.png',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 10),
          // App name + section
          Text(
            'InkSync - $headerTitle',
            style: TextStyle(
              fontSize: isWide ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          const Spacer(),
          // Sync Indicator
          if (!kIsWeb) ...[
            if (!authService.isLoggedIn)
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Sign in to sync across your devices'),
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      duration: const Duration(seconds: 4),
                      action: SnackBarAction(
                        label: 'Sign in',
                        textColor: AppTheme.primaryColor,
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                      ),
                    ),
                  );
                },
                child: Icon(Icons.cloud_off_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey),
              )
            else if (widget.isSyncing)
              const SizedBox(
                width: 14, 
                height: 14, 
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor)
              )
            else if (_hasUnsyncedChanges)
              Icon(Icons.sync_problem_rounded, size: 18, color: isDark ? Colors.white54 : Colors.grey)
            else
              const Icon(Icons.cloud_done_rounded, size: 18, color: Colors.green),
          ],
        ],
      ),
    );
  }

  Widget _buildGlobalSearchBar(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      height: 44,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          Icon(
            Icons.search_rounded,
            color: AppTheme.primaryColor.withValues(alpha: 0.7),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _globalSearchController,
              focusNode: _globalSearchFocusNode,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: 'Search all notes, checklists, tags...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.grey,
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (query) {
                setState(() => _globalSearchQuery = query.trim());
              },
            ),
          ),
          if (_globalSearchController.text.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: isDark ? Colors.white54 : Colors.grey,
                size: 18,
              ),
              onPressed: () {
                _globalSearchController.clear();
                setState(() => _globalSearchQuery = '');
              },
            ),
          IconButton(
            icon: Icon(
              Icons.close_rounded,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              size: 20,
            ),
            tooltip: 'Close search',
            onPressed: deactivateSearch,
          ),
        ],
      ),
    );
  }

  Widget _buildTagTabs(bool isDark) {
    final scrollController = ScrollController();
    return Container(
      height: 44,
      margin: const EdgeInsets.only(top: 4),
      child: Scrollbar(
        controller: scrollController,
        thumbVisibility: false,
        child: ListView(
          controller: scrollController,
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          physics: const BouncingScrollPhysics(),
          children: [
            // "All" tab
            _buildTagTab(
              name: 'All',
              isSelected: _selectedTagName == null,
              onTap: () => setState(() => _selectedTagName = null),
              isDark: isDark,
            ),
            // Tag tabs
            ..._tags.map(
              (tag) => _buildTagTab(
                name: tag.name,
                isSelected: _selectedTagName?.toLowerCase() == tag.name.toLowerCase(),
                onTap: () => setState(() => _selectedTagName = tag.name),
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagTab({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor
              : isDark
              ? Colors.white10
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected
                  ? Colors.white
                  : isDark
                  ? Colors.white70
                  : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      elevation: 8,
      child: const SizedBox(height: 56),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.note_add_outlined,
              size: 48,
              color: isDark ? Colors.white24 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No notes yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap + to create your first note',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesView(String viewMode) {
    switch (viewMode) {
      case 'list':
        return _buildListView();
      case 'details':
        return _buildDetailsView();
      case 'grid':
      case 'large-grid': // Fallback for old settings
        return _buildGridView(isLarge: false);
      default:
        return _buildListView();
    }
  }

  Widget _buildListView() {
    final notes = _filteredNotes;
    return Consumer<SelectionProvider>(
      builder: (context, selectionProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              viewMode: 'list',
              isSelected: selectionProvider.selectedNote?.id == note.id,
              isHighlighted: _highlightedNoteId == note.id,
              onTap: () => _openNote(note),
              onLongPress: () => _showNoteContextMenu(note),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailsView() {
    final notes = _filteredNotes;
    return Consumer<SelectionProvider>(
      builder: (context, selectionProvider, child) {
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 100),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              viewMode: 'details',
              isSelected: selectionProvider.selectedNote?.id == note.id,
              isHighlighted: _highlightedNoteId == note.id,
              onTap: () => _openNote(note),
              onLongPress: () => _showNoteContextMenu(note),
            );
          },
        );
      },
    );
  }

  Widget _buildGridView({required bool isLarge}) {
    final notes = _filteredNotes;
    return Consumer<SelectionProvider>(
      builder: (context, selectionProvider, child) {
        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: isLarge ? 0.75 : 0.9,
          ),
          itemCount: notes.length,
          itemBuilder: (context, index) {
            final note = notes[index];
            return NoteCard(
              key: ValueKey(note.id),
              note: note,
              viewMode: isLarge ? 'large-grid' : 'grid',
              isSelected: selectionProvider.selectedNote?.id == note.id,
              isHighlighted: _highlightedNoteId == note.id,
              onTap: () => _openNote(note),
              onLongPress: () => _showNoteContextMenu(note),
            );
          },
        );
      },
    );
  }
}

/// Context menu for long-press on notes
class _NoteContextMenu extends StatelessWidget {
  final Note note;
  final bool isCreator;
  final VoidCallback onPin;
  final VoidCallback onDelete;
  final VoidCallback onOpen;
  final VoidCallback onMore;

  const _NoteContextMenu({
    required this.note,
    required this.isCreator,
    required this.onPin,
    required this.onDelete,
    required this.onOpen,
    required this.onMore,
  });

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
      padding: EdgeInsets.fromLTRB(24, 16, 24, isDesktop ? 24 : 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isDesktop) ...[
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            note.title.isEmpty ? 'Untitled' : note.title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 18,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildAction(
                context,
                icon: note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                label: note.isPinned ? 'Unpin' : 'Pin',
                onTap: onPin,
              ),
              _buildAction(
                context,
                icon: Icons.open_in_new_rounded,
                label: 'Open',
                onTap: onOpen,
              ),
              _buildAction(
                context,
                icon: isCreator ? Icons.delete_outline_rounded : Icons.exit_to_app_rounded,
                label: isCreator ? 'Delete' : 'Leave',
                color: Colors.red,
                onTap: onDelete,
              ),
              _buildAction(
                context,
                icon: Icons.more_horiz_rounded,
                label: 'More',
                onTap: onMore,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white70 : AppTheme.textSecondary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, color: color ?? defaultColor, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color ?? defaultColor),
            ),
          ],
        ),
      ),
    );
  }
}
