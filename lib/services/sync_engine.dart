import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_database_service.dart';
import 'auth_service.dart';

/// SyncEngine — Bidirectional delta sync between SQLite and Supabase.
/// Runs only on mobile (guarded by kIsWeb checks at the call site).
///
/// Strategy:
///   1. PUSH all locally-changed records to Supabase.
///   2. PULL all server records changed since `last_synced_at`.
///   3. LWW (Last-Write-Wins) conflict resolution using UTC timestamps.
class SyncEngine {
  final LocalDatabaseService _localDb;
  final AuthService _auth;

  static bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  /// Stream controller to notify the UI of sync state changes
  final ValueNotifier<bool> syncingNotifier = ValueNotifier(false);
  final ValueNotifier<DateTime?> lastSyncNotifier = ValueNotifier(null);

  SyncEngine(this._localDb, this._auth);

  SupabaseClient get _client => Supabase.instance.client;

  String? get _userId => _auth.currentUserId;

  /// Perform a full bidirectional sync. Safe to call frequently —
  /// concurrent calls are debounced via the `_isSyncing` guard.
  Future<void> sync() async {
    // No sync without authentication
    if (_userId == null || _userId!.isEmpty) {
      debugPrint('SyncEngine: Skipping sync — user not authenticated');
      return;
    }

    if (_isSyncing) {
      debugPrint('SyncEngine: Sync already in progress, skipping');
      return;
    }

    _isSyncing = true;
    syncingNotifier.value = true;

    try {
      debugPrint('SyncEngine: Starting sync for user $_userId');

      // Step 1: PUSH local changes to server
      await _pushNotes();
      await _pushTags();

      // Step 2: PULL server changes to local
      await _pullNotes();
      await _pullTags();
      await _pullUserSettings();

      // Step 3: Update the sync checkpoint
      final now = DateTime.now().toUtc().toIso8601String();
      await _localDb.setLastSyncTimestamp(now);
      lastSyncNotifier.value = DateTime.now();

      debugPrint('SyncEngine: Sync completed successfully');
    } catch (e) {
      debugPrint('SyncEngine: Sync failed — $e');
    } finally {
      _isSyncing = false;
      syncingNotifier.value = false;
    }
  }

  // ===========================================================
  // PUSH — Local → Server
  // ===========================================================

  Future<void> _pushNotes() async {
    final pending = await _localDb.getPendingNotes();
    debugPrint('SyncEngine: Pushing ${pending.length} pending notes');

    for (final row in pending) {
      final noteId = row['id'] as String;
      final status = row['sync_status'] as int;

      try {
        if (status == SyncStatus.pendingInsert) {
          await _pushInsertNote(row);
        } else if (status == SyncStatus.pendingUpdate) {
          await _pushUpdateNote(row);
        } else if (status == SyncStatus.pendingDelete) {
          await _pushDeleteNote(noteId);
        }
      } catch (e) {
        debugPrint('SyncEngine: Failed to push note $noteId — $e');
        // Continue with remaining notes
      }
    }
  }

  Future<void> _pushInsertNote(Map<String, dynamic> row) async {
    final data = _prepareNoteForServer(row);
    data['user_id'] = _userId;

    try {
      await _client.from('notes').insert(data);
      await _localDb.markNoteSynced(row['id'] as String);
      debugPrint('SyncEngine: Inserted note ${row['id']}');
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        // Duplicate key — note already exists on server, convert to update
        await _pushUpdateNote(row);
      } else {
        rethrow;
      }
    }
  }

  Future<void> _pushUpdateNote(Map<String, dynamic> row) async {
    final data = _prepareNoteForServer(row);
    await _client.from('notes').update(data).eq('id', row['id'] as String);
    await _localDb.markNoteSynced(row['id'] as String);
    debugPrint('SyncEngine: Updated note ${row['id']}');
  }

  Future<void> _pushDeleteNote(String noteId) async {
    try {
      await _client.from('notes').delete().eq('id', noteId);
    } catch (_) {
      // Already deleted on server — that's fine
    }
    await _localDb.purgeDeletedNote(noteId);
    debugPrint('SyncEngine: Deleted note $noteId');
  }

  Future<void> _pushTags() async {
    final pending = await _localDb.getPendingTags();
    debugPrint('SyncEngine: Pushing ${pending.length} pending tags');

    for (final row in pending) {
      final tagId = row['id'] as String;
      final status = row['sync_status'] as int;

      try {
        if (status == SyncStatus.pendingInsert) {
          final data = _prepareTagForServer(row);
          data['user_id'] = _userId;
          try {
            await _client.from('tags').insert(data);
          } on PostgrestException catch (e) {
            if (e.code == '23505') {
              await _client.from('tags').update(data).eq('id', tagId);
            } else {
              rethrow;
            }
          }
          await _localDb.markTagSynced(tagId);
        } else if (status == SyncStatus.pendingUpdate) {
          final data = _prepareTagForServer(row);
          await _client.from('tags').update(data).eq('id', tagId);
          await _localDb.markTagSynced(tagId);
        } else if (status == SyncStatus.pendingDelete) {
          try {
            await _client.from('tags').delete().eq('id', tagId);
          } catch (_) {}
          await _localDb.purgeDeletedTag(tagId);
        }
      } catch (e) {
        debugPrint('SyncEngine: Failed to push tag $tagId — $e');
      }
    }
  }

  // ===========================================================
  // PULL — Server → Local (Delta)
  // ===========================================================

  Future<void> _pullNotes() async {
    final lastSync = await _localDb.getLastSyncTimestamp();

    List<dynamic> serverNotes;
    if (lastSync != null) {
      // Delta: only notes updated after last sync
      serverNotes = await _client
          .from('notes')
          .select()
          .eq('user_id', _userId!)
          .gt('updated_at', lastSync)
          .order('updated_at', ascending: false);
    } else {
      // First sync: pull everything
      serverNotes = await _client
          .from('notes')
          .select()
          .eq('user_id', _userId!)
          .order('updated_at', ascending: false);
    }

    debugPrint('SyncEngine: Pulled ${serverNotes.length} notes from server');

    for (final serverNote in serverNotes) {
      final noteId = serverNote['id'] as String;

      // Check for local version
      final localNote = await _localDb.getNote(noteId);

      if (localNote == null) {
        // New note from server — insert locally
        await _localDb.upsertNoteFromServer(Map<String, dynamic>.from(serverNote));
      } else {
        // LWW: Compare UTC timestamps
        final serverUpdated = DateTime.parse(serverNote['updated_at'] as String);
        final localUpdated = localNote.updatedDate ?? DateTime(0);

        if (serverUpdated.isAfter(localUpdated)) {
          // Server wins
          await _localDb.upsertNoteFromServer(Map<String, dynamic>.from(serverNote));
        }
        // Otherwise local version is newer (pending push) — skip
      }
    }
  }

  Future<void> _pullTags() async {
    final lastSync = await _localDb.getLastSyncTimestamp();

    List<dynamic> serverTags;
    if (lastSync != null) {
      serverTags = await _client
          .from('tags')
          .select()
          .eq('user_id', _userId!)
          .gt('updated_at', lastSync)
          .order('order', ascending: true);
    } else {
      serverTags = await _client
          .from('tags')
          .select()
          .eq('user_id', _userId!)
          .order('order', ascending: true);
    }

    debugPrint('SyncEngine: Pulled ${serverTags.length} tags from server');

    for (final serverTag in serverTags) {
      await _localDb.upsertTagFromServer(Map<String, dynamic>.from(serverTag));
    }
  }

  Future<void> _pullUserSettings() async {
    try {
      final serverSettings = await _client
          .from('user_settings')
          .select()
          .eq('user_id', _userId!)
          .maybeSingle();

      if (serverSettings != null) {
        await _localDb.upsertUserSettings(Map<String, dynamic>.from(serverSettings));
      }
    } catch (e) {
      debugPrint('SyncEngine: Failed to pull user_settings — $e');
    }
  }

  // ===========================================================
  // Data Preparation Helpers
  // ===========================================================

  /// Strip SQLite-only fields and prepare for Supabase insert/update
  Map<String, dynamic> _prepareNoteForServer(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    data.remove('sync_status');

    // Decode JSON strings back to proper types for Supabase
    if (data['checklist_items'] is String) {
      data['checklist_items'] = _safeDecode(data['checklist_items'] as String);
    }
    if (data['collaborators'] is String) {
      try {
        data['collaborators'] = _safeDecode(data['collaborators'] as String);
      } catch (_) {
        data['collaborators'] = [];
      }
    }
    if (data['tags'] is String) {
      try {
        data['tags'] = _safeDecode(data['tags'] as String);
      } catch (_) {
        data['tags'] = [];
      }
    }

    // Convert SQLite integers back to booleans
    data['is_pinned'] = data['is_pinned'] == 1;
    data['is_pinned_to_notifications'] = data['is_pinned_to_notifications'] == 1;
    data['is_locked'] = data['is_locked'] == 1;
    data['title_set_manually'] = data['title_set_manually'] == 1;

    return data;
  }

  Map<String, dynamic> _prepareTagForServer(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row);
    data.remove('sync_status');
    return data;
  }

  dynamic _safeDecode(String json) {
    try {
      return jsonDecode(json);
    } catch (_) {
      return [];
    }
  }
}


