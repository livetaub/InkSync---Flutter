import 'package:supabase_flutter/supabase_flutter.dart';
import 'notes_service.dart'; // Reuse models: Note, ChecklistItem, Collaborator

/// Supabase Notes Service - PostgreSQL CRUD operations
///
/// This service mirrors the NotesService API but uses Supabase instead of Firestore.
/// Uses native Supabase Auth for user identification.
class SupabaseNotesService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get current authenticated user ID from Supabase Auth
  String get userId => _client.auth.currentUser?.id ?? '';

  /// Get current user email
  String get userEmail => _client.auth.currentUser?.email ?? '';

  // ===========================================================
  // Note CRUD Operations
  // ===========================================================

  /// Get all notes for current user (real-time stream)
  Stream<List<Note>> getNotesStream() {
    return _client
        .from('notes')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('updated_at', ascending: false)
        .map((data) => data.map((row) => _noteFromSupabase(row)).toList());
  }

  /// Get all notes (one-time fetch)
  Future<List<Note>> getNotes() async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);

    return (response as List).map((row) => _noteFromSupabase(row)).toList();
  }

  /// Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('id', noteId)
          .single();
      return _noteFromSupabase(response);
    } catch (e) {
      return null;
    }
  }

  /// Create a new note
  Future<Note> createNote(Note note) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final data = _noteToSupabase(note);
    data['user_id'] = userId;
    data['created_at'] = now;
    data['updated_at'] = now;

    final response = await _client.from('notes').insert(data).select().single();

    return _noteFromSupabase(response);
  }

  /// Update an existing note
  Future<void> updateNote(String noteId, Map<String, dynamic> updates) async {
    // Convert field names from Firestore to Supabase naming convention
    final supabaseUpdates = _convertUpdatesToSupabase(updates);
    supabaseUpdates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    await _client.from('notes').update(supabaseUpdates).eq('id', noteId);
  }

  /// Delete a note permanently
  Future<void> deleteNote(String noteId) async {
    await _client.from('notes').delete().eq('id', noteId);
  }

  /// Move note to trash (soft delete)
  Future<void> trashNote(String noteId) async {
    await updateNote(noteId, {'trashedAt': DateTime.now().toIso8601String()});
  }

  /// Restore note from trash
  Future<void> restoreNote(String noteId) async {
    await _client.from('notes').update({'trashed_at': null}).eq('id', noteId);
  }

  /// Get trashed notes
  Future<List<Note>> getTrashedNotes() async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .not('trashed_at', 'is', null)
        .order('updated_at', ascending: false);

    return (response as List).map((row) => _noteFromSupabase(row)).toList();
  }

  /// Get active (non-trashed) notes
  Future<List<Note>> getActiveNotes() async {
    final response = await _client
        .from('notes')
        .select()
        .eq('user_id', userId)
        .isFilter('trashed_at', null)
        .order('updated_at', ascending: false);

    return (response as List).map((row) => _noteFromSupabase(row)).toList();
  }

  // ===========================================================
  // Data Conversion Helpers
  // ===========================================================

  /// Convert Supabase row to Note model
  Note _noteFromSupabase(Map<String, dynamic> row) {
    return Note(
      id: row['id'],
      title: row['title'] ?? '',
      content: row['content'] ?? '',
      type: row['type'] ?? 'text',
      checklistItems: _parseChecklistItems(row['checklist_items']),
      color: row['color'] ?? '#10B981',
      isPinned: row['is_pinned'] ?? false,
      isPinnedToNotifications: row['is_pinned_to_notifications'] ?? false,
      isLocked: row['is_locked'] ?? false,
      lockPassword: row['lock_password'],
      trashedAt: row['trashed_at'],
      reminderAt: row['reminder_at'] != null
          ? DateTime.parse(row['reminder_at'])
          : null,
      collaborators: _parseCollaborators(row['collaborators']),
      createdBy: row['created_by'],
      createdDate: row['created_at'] != null
          ? DateTime.parse(row['created_at'])
          : null,
      updatedDate: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'])
          : null,
      tags: List<String>.from(row['tags'] ?? []),
    );
  }

  /// Convert Note model to Supabase insert format
  Map<String, dynamic> _noteToSupabase(Note note) {
    return {
      'title': note.title,
      'content': note.content,
      'type': note.type,
      'checklist_items': note.checklistItems.map((i) => i.toMap()).toList(),
      'color': note.color,
      'is_pinned': note.isPinned,
      'is_pinned_to_notifications': note.isPinnedToNotifications,
      'is_locked': note.isLocked,
      'lock_password': note.lockPassword,
      'trashed_at': note.trashedAt,
      'reminder_at': note.reminderAt?.toIso8601String(),
      'collaborators': note.collaborators.map((c) => c.toMap()).toList(),
      'created_by': note.createdBy,
      'tags': note.tags,
    };
  }

  /// Convert Firestore field names to Supabase snake_case
  Map<String, dynamic> _convertUpdatesToSupabase(Map<String, dynamic> updates) {
    final Map<String, String> fieldMapping = {
      'title': 'title',
      'content': 'content',
      'type': 'type',
      'checklistItems': 'checklist_items',
      'color': 'color',
      'isPinned': 'is_pinned',
      'isPinnedToNotifications': 'is_pinned_to_notifications',
      'isLocked': 'is_locked',
      'lockPassword': 'lock_password',
      'trashedAt': 'trashed_at',
      'reminderAt': 'reminder_at',
      'collaborators': 'collaborators',
      'created_by': 'created_by',
      'updated_date': 'updated_at',
      'tags': 'tags',
    };

    final result = <String, dynamic>{};
    updates.forEach((key, value) {
      final supabaseKey = fieldMapping[key] ?? key;
      result[supabaseKey] = value;
    });
    return result;
  }

  List<ChecklistItem> _parseChecklistItems(dynamic data) {
    if (data == null) return [];
    return (data as List)
        .map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }

  List<Collaborator> _parseCollaborators(dynamic data) {
    if (data == null) return [];
    return (data as List)
        .map((item) => Collaborator.fromMap(Map<String, dynamic>.from(item)))
        .toList();
  }
}
