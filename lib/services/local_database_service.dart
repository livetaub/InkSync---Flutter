import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'notes_service.dart';

/// Sync status constants for local-first architecture
class SyncStatus {
  static const int synced = 0;
  static const int pendingInsert = 1;
  static const int pendingUpdate = 2;
  static const int pendingDelete = 3;
}

/// LocalDatabaseService — SQLite engine for offline-first mobile storage.
/// This is the single source of truth on mobile devices.
/// The web app continues to use Supabase directly.
class LocalDatabaseService {
  static LocalDatabaseService? _instance;
  static LocalDatabaseService get instance {
    _instance ??= LocalDatabaseService._();
    return _instance!;
  }

  LocalDatabaseService._();

  Database? _db;

  /// Get the database instance, initializing if needed
  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'inksync_local.db');
    debugPrint('LocalDB: Initializing at $path');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  /// Create all tables on first launch
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('LocalDB: Creating tables (v$version)');

    // Notes table — mirrors Supabase `notes` schema + sync columns
    await db.execute('''
      CREATE TABLE notes (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        title TEXT NOT NULL DEFAULT '',
        content TEXT NOT NULL DEFAULT '',
        type TEXT NOT NULL DEFAULT 'text',
        checklist_items TEXT DEFAULT '[]',
        color TEXT NOT NULL DEFAULT 'yellow',
        is_pinned INTEGER NOT NULL DEFAULT 0,
        is_pinned_to_notifications INTEGER NOT NULL DEFAULT 0,
        is_locked INTEGER NOT NULL DEFAULT 0,
        lock_password TEXT,
        trashed_at TEXT,
        reminder_at TEXT,
        collaborators TEXT DEFAULT '[]',
        created_by TEXT,
        tags TEXT DEFAULT '[]',
        title_set_manually INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Tags table — mirrors Supabase `tags` schema + sync columns
    await db.execute('''
      CREATE TABLE tags (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        name TEXT NOT NULL,
        type TEXT NOT NULL DEFAULT 'text',
        color TEXT NOT NULL DEFAULT '#10B981',
        "order" INTEGER NOT NULL DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // User settings table — mirrors Supabase `user_settings` + sync columns
    await db.execute('''
      CREATE TABLE user_settings (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        sort_order TEXT DEFAULT 'updatedDate',
        sort_ascending INTEGER DEFAULT 0,
        default_color TEXT DEFAULT '#10B981',
        haptic_enabled INTEGER DEFAULT 1,
        is_premium INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT,
        sync_status INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Sync metadata table — tracks last successful sync timestamp
    await db.execute('''
      CREATE TABLE sync_meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
  }

  // ===========================================================
  // Notes CRUD
  // ===========================================================

  /// Insert a new note into the local database
  Future<void> insertNote(Map<String, dynamic> noteData) async {
    final db = await database;
    // Serialize list fields to JSON strings
    noteData['checklist_items'] = jsonEncode(noteData['checklist_items'] ?? []);
    noteData['collaborators'] = jsonEncode(noteData['collaborators'] ?? []);
    noteData['tags'] = jsonEncode(noteData['tags'] ?? []);

    await db.insert('notes', noteData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Get all active (non-trashed) notes for a user
  Future<List<Note>> getActiveNotes(String? userId) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (userId != null && userId.isNotEmpty) {
      rows = await db.query(
        'notes',
        where: 'user_id = ? AND trashed_at IS NULL AND sync_status != ?',
        whereArgs: [userId, SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    } else {
      // Guest mode — get all local notes
      rows = await db.query(
        'notes',
        where: 'trashed_at IS NULL AND sync_status != ?',
        whereArgs: [SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    }

    return rows.map(_rowToNote).toList();
  }

  /// Get trashed notes
  Future<List<Note>> getTrashedNotes(String? userId) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (userId != null && userId.isNotEmpty) {
      rows = await db.query(
        'notes',
        where: 'user_id = ? AND trashed_at IS NOT NULL AND sync_status != ?',
        whereArgs: [userId, SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    } else {
      rows = await db.query(
        'notes',
        where: 'trashed_at IS NOT NULL AND sync_status != ?',
        whereArgs: [SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    }

    return rows.map(_rowToNote).toList();
  }

  /// Get all notes (active + trashed) for a user
  Future<List<Note>> getNotes(String? userId) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (userId != null && userId.isNotEmpty) {
      rows = await db.query(
        'notes',
        where: 'user_id = ? AND sync_status != ?',
        whereArgs: [userId, SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    } else {
      rows = await db.query(
        'notes',
        where: 'sync_status != ?',
        whereArgs: [SyncStatus.pendingDelete],
        orderBy: 'updated_at DESC',
      );
    }

    return rows.map(_rowToNote).toList();
  }

  /// Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    final db = await database;
    final rows = await db.query('notes', where: 'id = ?', whereArgs: [noteId]);
    if (rows.isEmpty) return null;
    return _rowToNote(rows.first);
  }

  /// Update a note and mark it as pending sync
  Future<void> updateNote(String noteId, Map<String, dynamic> updates) async {
    final db = await database;

    // Serialize list fields if present
    if (updates.containsKey('checklist_items')) {
      updates['checklist_items'] = jsonEncode(updates['checklist_items']);
    }
    if (updates.containsKey('collaborators')) {
      updates['collaborators'] = jsonEncode(updates['collaborators']);
    }
    if (updates.containsKey('tags')) {
      updates['tags'] = jsonEncode(updates['tags']);
    }

    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    // Only mark as pending update if currently synced
    final existing = await db.query('notes', where: 'id = ?', whereArgs: [noteId], columns: ['sync_status']);
    if (existing.isNotEmpty && existing.first['sync_status'] == SyncStatus.synced) {
      updates['sync_status'] = SyncStatus.pendingUpdate;
    }

    await db.update('notes', updates, where: 'id = ?', whereArgs: [noteId]);
  }

  /// Soft-delete: mark as trashed
  Future<void> trashNote(String noteId) async {
    await updateNote(noteId, {'trashed_at': DateTime.now().toIso8601String()});
  }

  /// Restore from trash
  Future<void> restoreNote(String noteId) async {
    final db = await database;
    await db.update(
      'notes',
      {
        'trashed_at': null,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        'sync_status': SyncStatus.pendingUpdate,
      },
      where: 'id = ?',
      whereArgs: [noteId],
    );
  }

  /// Hard-delete: mark for permanent deletion sync
  Future<void> deleteNote(String noteId) async {
    final db = await database;
    final existing = await db.query('notes', where: 'id = ?', whereArgs: [noteId], columns: ['sync_status']);

    if (existing.isNotEmpty && existing.first['sync_status'] == SyncStatus.pendingInsert) {
      // Never synced — just delete locally
      await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
    } else {
      // Mark for deletion during next sync
      await db.update(
        'notes',
        {'sync_status': SyncStatus.pendingDelete},
        where: 'id = ?',
        whereArgs: [noteId],
      );
    }
  }

  /// Empty trash
  Future<void> emptyTrash(String? userId) async {
    final db = await database;
    // Get all trashed notes
    final where = userId != null
        ? 'user_id = ? AND trashed_at IS NOT NULL'
        : 'trashed_at IS NOT NULL';
    final whereArgs = userId != null ? [userId] : null;

    final trashed = await db.query('notes', where: where, whereArgs: whereArgs, columns: ['id', 'sync_status']);

    for (final row in trashed) {
      if (row['sync_status'] == SyncStatus.pendingInsert) {
        await db.delete('notes', where: 'id = ?', whereArgs: [row['id']]);
      } else {
        await db.update('notes', {'sync_status': SyncStatus.pendingDelete}, where: 'id = ?', whereArgs: [row['id']]);
      }
    }
  }

  /// Get all notes pending sync
  Future<List<Map<String, dynamic>>> getPendingNotes() async {
    final db = await database;
    return await db.query('notes', where: 'sync_status != ?', whereArgs: [SyncStatus.synced]);
  }

  /// Mark a note as synced
  Future<void> markNoteSynced(String noteId) async {
    final db = await database;
    await db.update('notes', {'sync_status': SyncStatus.synced}, where: 'id = ?', whereArgs: [noteId]);
  }

  /// Remove a note that was confirmed deleted on the server
  Future<void> purgeDeletedNote(String noteId) async {
    final db = await database;
    await db.delete('notes', where: 'id = ?', whereArgs: [noteId]);
  }

  /// Upsert a note from the server (used during pull sync)
  Future<void> upsertNoteFromServer(Map<String, dynamic> serverData) async {
    final db = await database;
    serverData['sync_status'] = SyncStatus.synced;
    serverData['checklist_items'] = jsonEncode(serverData['checklist_items'] ?? []);
    serverData['collaborators'] = jsonEncode(serverData['collaborators'] ?? []);
    serverData['tags'] = jsonEncode(serverData['tags'] ?? []);
    // Convert booleans to integers for SQLite
    serverData['is_pinned'] = (serverData['is_pinned'] == true) ? 1 : 0;
    serverData['is_pinned_to_notifications'] = (serverData['is_pinned_to_notifications'] == true) ? 1 : 0;
    serverData['is_locked'] = (serverData['is_locked'] == true) ? 1 : 0;
    serverData['title_set_manually'] = (serverData['title_set_manually'] == true) ? 1 : 0;

    // Ensure created_by is always populated (Supabase may not have this column)
    serverData['created_by'] ??= serverData['user_id'];

    await db.insert('notes', serverData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===========================================================
  // Tags CRUD
  // ===========================================================

  /// Get all tags for a user
  Future<List<Tag>> getTags(String? userId) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (userId != null && userId.isNotEmpty) {
      rows = await db.query('tags', where: 'user_id = ? AND sync_status != ?',
          whereArgs: [userId, SyncStatus.pendingDelete], orderBy: '"order" ASC');
    } else {
      rows = await db.query('tags', where: 'sync_status != ?',
          whereArgs: [SyncStatus.pendingDelete], orderBy: '"order" ASC');
    }

    return rows.map((row) => Tag(
      id: row['id'] as String?,
      name: row['name'] as String? ?? '',
      type: row['type'] as String? ?? 'text',
      color: row['color'] as String? ?? '#10B981',
      order: row['order'] as int? ?? 0,
    )).toList();
  }

  /// Get tags by type
  Future<List<Tag>> getTagsByType(String? userId, String type) async {
    final db = await database;
    List<Map<String, dynamic>> rows;

    if (userId != null && userId.isNotEmpty) {
      rows = await db.query('tags',
          where: 'user_id = ? AND type = ? AND sync_status != ?',
          whereArgs: [userId, type, SyncStatus.pendingDelete],
          orderBy: '"order" ASC');
    } else {
      rows = await db.query('tags',
          where: 'type = ? AND sync_status != ?',
          whereArgs: [type, SyncStatus.pendingDelete],
          orderBy: '"order" ASC');
    }

    return rows.map((row) => Tag(
      id: row['id'] as String?,
      name: row['name'] as String? ?? '',
      type: row['type'] as String? ?? 'text',
      color: row['color'] as String? ?? '#10B981',
      order: row['order'] as int? ?? 0,
    )).toList();
  }

  /// Insert a tag
  Future<void> insertTag(Map<String, dynamic> tagData) async {
    final db = await database;
    await db.insert('tags', tagData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Update a tag
  Future<void> updateTag(String tagId, Map<String, dynamic> updates) async {
    final db = await database;
    final existing = await db.query('tags', where: 'id = ?', whereArgs: [tagId], columns: ['sync_status']);
    if (existing.isNotEmpty && existing.first['sync_status'] == SyncStatus.synced) {
      updates['sync_status'] = SyncStatus.pendingUpdate;
    }
    await db.update('tags', updates, where: 'id = ?', whereArgs: [tagId]);
  }

  /// Delete a tag
  Future<void> deleteTag(String tagId) async {
    final db = await database;
    final existing = await db.query('tags', where: 'id = ?', whereArgs: [tagId], columns: ['sync_status']);
    if (existing.isNotEmpty && existing.first['sync_status'] == SyncStatus.pendingInsert) {
      await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
    } else {
      await db.update('tags', {'sync_status': SyncStatus.pendingDelete}, where: 'id = ?', whereArgs: [tagId]);
    }
  }

  /// Get tag by ID
  Future<Tag?> getTag(String tagId) async {
    final db = await database;
    final rows = await db.query('tags', where: 'id = ?', whereArgs: [tagId]);
    if (rows.isEmpty) return null;
    final row = rows.first;
    return Tag(
      id: row['id'] as String?,
      name: row['name'] as String? ?? '',
      type: row['type'] as String? ?? 'text',
      color: row['color'] as String? ?? '#10B981',
      order: row['order'] as int? ?? 0,
    );
  }

  /// Reorder tags
  Future<void> reorderTags(List<Tag> tags) async {
    final db = await database;
    await db.transaction((txn) async {
      for (int i = 0; i < tags.length; i++) {
        final tag = tags[i];
        if (tag.id != null) {
          await txn.update(
            'tags',
            {'order': i, 'sync_status': SyncStatus.pendingUpdate},
            where: 'id = ?',
            whereArgs: [tag.id],
          );
        }
      }
    });
  }

  /// Get all tags pending sync
  Future<List<Map<String, dynamic>>> getPendingTags() async {
    final db = await database;
    return await db.query('tags', where: 'sync_status != ?', whereArgs: [SyncStatus.synced]);
  }

  /// Mark a tag as synced
  Future<void> markTagSynced(String tagId) async {
    final db = await database;
    await db.update('tags', {'sync_status': SyncStatus.synced}, where: 'id = ?', whereArgs: [tagId]);
  }

  /// Upsert a tag from the server
  Future<void> upsertTagFromServer(Map<String, dynamic> serverData) async {
    final db = await database;
    serverData['sync_status'] = SyncStatus.synced;
    await db.insert('tags', serverData, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Purge a deleted tag
  Future<void> purgeDeletedTag(String tagId) async {
    final db = await database;
    await db.delete('tags', where: 'id = ?', whereArgs: [tagId]);
  }

  // ===========================================================
  // User Settings
  // ===========================================================

  /// Get user settings
  Future<Map<String, dynamic>?> getUserSettings(String? userId) async {
    final db = await database;
    List<Map<String, dynamic>> rows;
    if (userId != null && userId.isNotEmpty) {
      rows = await db.query('user_settings', where: 'user_id = ?', whereArgs: [userId]);
    } else {
      rows = await db.query('user_settings', limit: 1);
    }
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Upsert user settings
  Future<void> upsertUserSettings(Map<String, dynamic> data) async {
    final db = await database;
    data['sync_status'] = SyncStatus.synced;
    await db.insert('user_settings', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===========================================================
  // Sync Metadata
  // ===========================================================

  /// Get last sync timestamp
  Future<String?> getLastSyncTimestamp() async {
    final db = await database;
    final rows = await db.query('sync_meta', where: 'key = ?', whereArgs: ['last_synced_at']);
    return rows.isNotEmpty ? rows.first['value'] as String? : null;
  }

  /// Set last sync timestamp
  Future<void> setLastSyncTimestamp(String timestamp) async {
    final db = await database;
    await db.insert('sync_meta', {'key': 'last_synced_at', 'value': timestamp},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ===========================================================
  // Guest → Authenticated Migration
  // ===========================================================

  /// Stamp all guest notes (user_id is null or empty) with a real user ID
  Future<int> migrateGuestData(String userId) async {
    final db = await database;
    int count = 0;

    // Migrate notes
    count += await db.update(
      'notes',
      {'user_id': userId, 'sync_status': SyncStatus.pendingInsert},
      where: 'user_id IS NULL OR user_id = ?',
      whereArgs: [''],
    );

    // Migrate tags
    count += await db.update(
      'tags',
      {'user_id': userId, 'sync_status': SyncStatus.pendingInsert},
      where: 'user_id IS NULL OR user_id = ?',
      whereArgs: [''],
    );

    debugPrint('LocalDB: Migrated $count guest records to user $userId');
    return count;
  }

  // ===========================================================
  // Helpers
  // ===========================================================

  /// Convert a SQLite row to a Note model
  Note _rowToNote(Map<String, dynamic> row) {
    return Note(
      id: row['id'] as String?,
      title: row['title'] as String? ?? '',
      content: row['content'] as String? ?? '',
      type: row['type'] as String? ?? 'text',
      checklistItems: _decodeChecklistItems(row['checklist_items']),
      color: row['color'] as String? ?? 'yellow',
      isPinned: (row['is_pinned'] as int?) == 1,
      isPinnedToNotifications: (row['is_pinned_to_notifications'] as int?) == 1,
      isLocked: (row['is_locked'] as int?) == 1,
      lockPassword: row['lock_password'] as String?,
      trashedAt: row['trashed_at'] as String?,
      reminderAt: row['reminder_at'] != null ? DateTime.tryParse(row['reminder_at'] as String) : null,
      collaborators: _decodeCollaborators(row['collaborators']),
      createdBy: row['user_id'] as String? ?? row['created_by'] as String?,
      createdDate: row['created_at'] != null ? DateTime.tryParse(row['created_at'] as String) : null,
      updatedDate: row['updated_at'] != null ? DateTime.tryParse(row['updated_at'] as String) : null,
      tags: _decodeTags(row['tags']),
      titleSetManually: (row['title_set_manually'] as int?) == 1,
    );
  }

  List<ChecklistItem> _decodeChecklistItems(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> items = raw is String ? jsonDecode(raw) : raw;
      return items.map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item))).toList();
    } catch (_) {
      return [];
    }
  }

  List<Collaborator> _decodeCollaborators(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> items = raw is String ? jsonDecode(raw) : raw;
      return items.map((c) => Collaborator.fromMap(Map<String, dynamic>.from(c))).toList();
    } catch (_) {
      return [];
    }
  }

  List<String> _decodeTags(dynamic raw) {
    if (raw == null) return [];
    try {
      final List<dynamic> items = raw is String ? jsonDecode(raw) : raw;
      return items.cast<String>();
    } catch (_) {
      return [];
    }
  }

  /// Close the database
  Future<void> close() async {
    final db = await database;
    await db.close();
    _db = null;
  }
}
