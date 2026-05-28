import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notes_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../note_edit/note_edit_screen.dart';
import '../../widgets/note_card.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  List<Note> _allNotes = [];
  List<Note> _filteredNotes = [];
  bool _isLoading = true;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _loadNotes();
    // Auto focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final notesService = NotesService(authService);
      final notes = await notesService.getActiveNotes();
      setState(() {
        _allNotes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _performSearch(String query) {
    if (query.trim().isEmpty) {
      setState(() {
        _filteredNotes = [];
        _hasSearched = false;
      });
      return;
    }

    final lowerQuery = query.toLowerCase();
    final results = _allNotes.where((note) {
      // Search in title
      if (note.title.toLowerCase().contains(lowerQuery)) return true;

      if (!note.isLocked) {
        // Search in content
        if (note.content.toLowerCase().contains(lowerQuery)) return true;

        // Search in checklist items
        if (note.checklistItems.any(
          (item) => item.text.toLowerCase().contains(lowerQuery),
        )) {
          return true;
        }
      }

      return false;
    }).toList();

    setState(() {
      _filteredNotes = results;
      _hasSearched = true;
    });
  }

  void _openNote(Note note) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NoteEditScreen(
        note: note,
        initialSearchQuery: _searchController.text.trim(),
      )),
    ).then((_) => _loadNotes());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            focusNode: _focusNode,
            style: TextStyle(
              color: isDark ? Colors.white : AppTheme.textPrimary,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              hintText: 'Search notes...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.grey,
                fontSize: 15,
              ),
              border: InputBorder.none,
              prefixIcon: Icon(
                Icons.search_rounded,
                color: isDark ? Colors.white38 : Colors.grey,
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        color: isDark ? Colors.white54 : Colors.grey,
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: _performSearch,
            onSubmitted: _performSearch,
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(isDark),
    );
  }

  Widget _buildContent(bool isDark) {
    if (!_hasSearched) {
      // Show empty state prompting user to search
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_rounded,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'Search your notes',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find notes by title, content, or checklist items',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    if (_filteredNotes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 64,
              color: isDark ? Colors.white24 : Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'No notes found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white54 : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white38 : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            '${_filteredNotes.length} result${_filteredNotes.length == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : AppTheme.textMuted,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _filteredNotes.length,
            itemBuilder: (context, index) {
              final note = _filteredNotes[index];
              return NoteCard(
                note: note,
                viewMode: 'list',
                onTap: () => _openNote(note),
                onLongPress: () {}, // No long press action in search
              );
            },
          ),
        ),
      ],
    );
  }
}
