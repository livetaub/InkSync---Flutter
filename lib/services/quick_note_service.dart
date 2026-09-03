import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'sync_engine.dart';
import '../models/quick_note.dart';
import 'package:uuid/uuid.dart';

/// Service for managing Quick Note messages and associated media storage.
class QuickNoteService {
  final SupabaseClient _client;
  final AuthService _authService;

  QuickNoteService(this._authService)
      : _client = Supabase.instance.client;

  String get _userId => _authService.currentUserId ?? '';

  void _triggerSync() {
    if (!kIsWeb) {
      SyncEngine(LocalDatabaseService.instance, _authService).sync().catchError((e) {
        debugPrint('QuickNote sync error: $e');
      });
    }
  }

  /// Fetches all quick note messages for the current user, ordered by `created_at` ASC.
  Future<List<QuickNote>> getMessages({bool forceRefresh = false}) async {
    if (!kIsWeb) {
      final db = LocalDatabaseService.instance;
      final localData = await db.getQuickNotes(_userId);
      return localData.map((e) => QuickNote.fromMap(e)).toList();
    }

    try {
      final response = await _client
          .from('quick_notes')
          .select()
          .eq('user_id', _userId)
          .order('created_at', ascending: true);

      return (response as List)
          .map((row) => QuickNote.fromMap(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      debugPrint('Error fetching quick notes messages: $e');
      return [];
    }
  }

  /// Inserts a new quick note message and returns the created message.
  Future<QuickNote?> sendMessage(QuickNote message) async {
    final msgWithId = message.id == null ? message.copyWith(id: const Uuid().v4()) : message;

    if (!kIsWeb) {
      final data = msgWithId.toMap();
      data['user_id'] = _userId;
      data['sync_status'] = 1; // pending_create
      
      await LocalDatabaseService.instance.insertQuickNote(data);
      _triggerSync();
      return QuickNote.fromMap(data);
    }

    try {
      final data = msgWithId.toSupabase();
      data['user_id'] = _userId;

      final response = await _client
          .from('quick_notes')
          .insert(data)
          .select()
          .single();

      return QuickNote.fromMap(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error sending quick note message: $e');
      return null;
    }
  }

  /// Updates a quick note message (e.g., for editing text).
  Future<void> updateMessage(String id, Map<String, dynamic> data) async {
    final updates = Map<String, dynamic>.from(data);
    updates['updated_at'] = DateTime.now().toUtc().toIso8601String();

    if (!kIsWeb) {
      updates['sync_status'] = 2; // pending_update
      await LocalDatabaseService.instance.updateQuickNote(id, updates);
      _triggerSync();
      return;
    }

    try {
      await _client
          .from('quick_notes')
          .update(updates)
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Error updating quick note message: $e');
      rethrow;
    }
  }

  /// Deletes a quick note message from the database.
  Future<void> deleteMessage(String id) async {
    if (!kIsWeb) {
      await LocalDatabaseService.instance.deleteQuickNote(id);
      _triggerSync();
      return;
    }

    try {
      await _client
          .from('quick_notes')
          .delete()
          .eq('id', id)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Error deleting quick note message: $e');
      rethrow;
    }
  }

  /// Uploads a file from local file path to Supabase Storage bucket 'quick-notes' and returns the public URL.
  Future<String> uploadMedia(String filePath, String fileName, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$_userId/$type/${timestamp}_$fileName';

      if (!kIsWeb) {
        final file = File(filePath);
        await _client.storage.from('quick-notes').upload(path, file);
      } else {
        throw UnsupportedError(
          'uploadMedia with file path is not supported on web. Use uploadMediaBytes instead.',
        );
      }

      return _client.storage.from('quick-notes').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading media: $e');
      rethrow;
    }
  }

  /// Uploads raw bytes (for web/voice) to Supabase Storage bucket 'quick-notes' and returns the public URL.
  Future<String> uploadMediaBytes(Uint8List bytes, String fileName, String type) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '$_userId/$type/${timestamp}_$fileName';

      await _client.storage.from('quick-notes').uploadBinary(path, bytes);

      return _client.storage.from('quick-notes').getPublicUrl(path);
    } catch (e) {
      debugPrint('Error uploading media bytes: $e');
      rethrow;
    }
  }

  /// Removes a file from Supabase storage using its public URL or storage path.
  Future<void> deleteMedia(String mediaUrl) async {
    try {
      final path = _extractStoragePath(mediaUrl);
      await _client.storage.from('quick-notes').remove([path]);
    } catch (e) {
      debugPrint('Error deleting media: $e');
      rethrow;
    }
  }

  /// Extracts the storage path from a public URL.
  String _extractStoragePath(String url) {
    if (!url.contains('quick-notes/')) return url;
    final parts = url.split('quick-notes/');
    if (parts.length > 1) {
      return Uri.decodeFull(parts[1].split('?').first);
    }
    return url;
  }
}
