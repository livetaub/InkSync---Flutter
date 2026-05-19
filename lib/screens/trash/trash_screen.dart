import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/notes_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';

class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  late NotesService _notesService;
  List<Note> _trashedNotes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  void _initService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _notesService = NotesService(authService);
    _loadTrashedNotes();
  }

  Future<void> _loadTrashedNotes() async {
    setState(() => _isLoading = true);
    try {
      final notes = await _notesService.getTrashedNotes();
      setState(() {
        _trashedNotes = notes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading trash: $e')),
        );
      }
    }
  }

  Future<void> _restoreNote(Note note) async {
    try {
      await _notesService.restoreNote(note.id!);
      _loadTrashedNotes();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Note restored')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error restoring note: $e')),
        );
      }
    }
  }

  Future<void> _permanentlyDelete(Note note) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete permanently?'),
        content: const Text(
          'This note will be permanently deleted. This action cannot be undone.',
        ),
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

    if (confirm == true) {
      try {
        await _notesService.deleteNote(note.id!);
        _loadTrashedNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Note permanently deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting note: $e')),
          );
        }
      }
    }
  }

  Future<void> _emptyTrash() async {
    if (_trashedNotes.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Empty trash?'),
        content: Text(
          'All ${_trashedNotes.length} note${_trashedNotes.length == 1 ? '' : 's'} will be permanently deleted. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Empty trash', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        for (final note in _trashedNotes) {
          await _notesService.deleteNote(note.id!);
        }
        _loadTrashedNotes();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trash emptied')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error emptying trash: $e')),
          );
        }
      }
    }
  }

  int _getDaysRemaining(String? trashedAt) {
    if (trashedAt == null) return 30;
    final trashedDate = DateTime.parse(trashedAt);
    final deleteDate = trashedDate.add(const Duration(days: 30));
    final remaining = deleteDate.difference(DateTime.now()).inDays;
    return remaining.clamp(0, 30);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Trash'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_trashedNotes.isNotEmpty)
            TextButton(
              onPressed: _emptyTrash,
              child: const Text(
                'Empty trash',
                style: TextStyle(color: Colors.red),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _trashedNotes.isEmpty
              ? _buildEmptyState()
              : _buildTrashList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline,
              size: 40,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Trash is empty',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Deleted notes will appear here',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrashList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.amber.shade200),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.amber.shade700, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notes in trash will be permanently deleted after 30 days',
                  style: TextStyle(
                    color: Colors.amber.shade900,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _trashedNotes.length,
            itemBuilder: (context, index) {
              final note = _trashedNotes[index];
              return _buildTrashedNoteCard(note);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrashedNoteCard(Note note) {
    final daysRemaining = _getDaysRemaining(note.trashedAt);
    final bgColor = AppTheme.getNoteColor(note.color);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: bgColor.withValues(alpha: 0.7),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isEmpty ? 'Untitled' : note.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        note.type == 'checklist'
                            ? '${note.checklistItems.length} items'
                            : note.content.isEmpty
                                ? 'No content'
                                : note.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: daysRemaining <= 7
                        ? Colors.red.shade100
                        : Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$daysRemaining days left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: daysRemaining <= 7
                          ? Colors.red.shade700
                          : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _restoreNote(note),
                    icon: const Icon(Icons.restore, size: 18),
                    label: const Text('Restore'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _permanentlyDelete(note),
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
