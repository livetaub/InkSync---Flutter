import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import 'local_database_service.dart';
import 'auth_service.dart';
import 'notes_service.dart';

/// LocalNotesService — Mobile-only service that reads/writes to SQLite.
/// Mirrors the NotesService API so the UI layer needs minimal changes.
class LocalNotesService {
  final LocalDatabaseService _localDb;
  final AuthService _auth;

  LocalNotesService(this._localDb, this._auth);

  String get _userId => _auth.currentUserId ?? '';

  // ===========================================================
  // Notes CRUD — delegates to LocalDatabaseService
  // ===========================================================

  /// Get all active (non-trashed) notes
  Future<List<Note>> getActiveNotes() async {
    return await _localDb.getActiveNotes(_userId.isEmpty ? null : _userId);
  }

  /// Get trashed notes
  Future<List<Note>> getTrashedNotes() async {
    return await _localDb.getTrashedNotes(_userId.isEmpty ? null : _userId);
  }

  /// Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    return await _localDb.getNote(noteId);
  }

  /// Create a new note — generates a UUID locally
  Future<Note?> createNote(Note note) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    final noteData = <String, dynamic>{
      'id': id,
      'user_id': _userId.isEmpty ? null : _userId,
      'title': note.title,
      'content': note.content,
      'type': note.type,
      'checklist_items': note.checklistItems.map((i) => i.toMap()).toList(),
      'color': note.color,
      'is_pinned': note.isPinned ? 1 : 0,
      'is_pinned_to_notifications': note.isPinnedToNotifications ? 1 : 0,
      'is_locked': note.isLocked ? 1 : 0,
      'lock_password': note.lockPassword,
      'trashed_at': note.trashedAt,
      'reminder_at': note.reminderAt?.toIso8601String(),
      'collaborators': note.collaborators.map((c) => c.toMap()).toList(),
      'created_by': _userId.isEmpty ? null : _userId,
      'tags': note.tags,
      'title_set_manually': note.titleSetManually ? 1 : 0,
      'created_at': now,
      'updated_at': now,
      'sync_status': _userId.isEmpty
          ? SyncStatus.synced  // Guest notes wait for migration
          : SyncStatus.pendingInsert,
    };

    await _localDb.insertNote(noteData);
    debugPrint('LocalNotesService: Created note $id');

    return note.copyWith(
      id: id,
      createdDate: DateTime.now().toUtc(),
      updatedDate: DateTime.now().toUtc(),
    );
  }

  /// Update an existing note
  Future<void> updateNote(String noteId, Map<String, dynamic> updates) async {
    // Convert camelCase keys to snake_case for SQLite
    final snakeUpdates = <String, dynamic>{};
    updates.forEach((key, value) {
      snakeUpdates[_toSnakeCase(key)] = value;
    });

    await _localDb.updateNote(noteId, snakeUpdates);
  }

  /// Delete a note permanently
  Future<void> deleteNote(String noteId) async {
    await _localDb.deleteNote(noteId);
  }

  /// Move note to trash
  Future<void> trashNote(String noteId) async {
    await _localDb.trashNote(noteId);
  }

  /// Restore note from trash
  Future<void> restoreNote(String noteId) async {
    await _localDb.restoreNote(noteId);
  }

  /// Empty trash
  Future<void> emptyTrash() async {
    await _localDb.emptyTrash(_userId.isEmpty ? null : _userId);
  }

  // ===========================================================
  // Tags CRUD
  // ===========================================================

  /// Get all tags
  Future<List<Tag>> getTags() async {
    return await _localDb.getTags(_userId.isEmpty ? null : _userId);
  }

  /// Get tags by type
  Future<List<Tag>> getTagsByType(String type) async {
    return await _localDb.getTagsByType(_userId.isEmpty ? null : _userId, type);
  }

  /// Create a new tag
  Future<String?> createTag(String name, {String type = 'text'}) async {
    final id = const Uuid().v4();
    final now = DateTime.now().toUtc().toIso8601String();

    // Get current max order
    final tags = await getTagsByType(type);
    final maxOrder = tags.isEmpty
        ? 0
        : tags.map((t) => t.order).reduce((a, b) => a > b ? a : b);

    await _localDb.insertTag({
      'id': id,
      'user_id': _userId.isEmpty ? null : _userId,
      'name': name,
      'type': type,
      'color': '#10B981',
      'order': maxOrder + 1,
      'created_at': now,
      'updated_at': now,
      'sync_status': _userId.isEmpty
          ? SyncStatus.synced
          : SyncStatus.pendingInsert,
    });

    return id;
  }

  /// Create default tags for new users
  Future<void> createDefaultTags() async {
    final existing = await getTags();
    if (existing.isNotEmpty) return;

    await createTag('Personal', type: 'text');
    await createTag('Work', type: 'text');
    await createTag('To Do', type: 'checklist');
    await createTag('Grocery List', type: 'checklist');
  }

  /// Update a tag
  Future<void> updateTag(String tagId, {String? name, String? color}) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (color != null) updates['color'] = color;
    if (updates.isNotEmpty) {
      await _localDb.updateTag(tagId, updates);
    }
  }

  /// Delete a tag
  Future<void> deleteTag(String tagId) async {
    await _localDb.deleteTag(tagId);
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  String _toSnakeCase(String input) {
    return input.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }
}
