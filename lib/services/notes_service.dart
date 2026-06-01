import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'local_notes_service.dart';
import 'sync_engine.dart';

/// Note Model
class Note {
  final String? id;
  final String title;
  final String content;
  final String type; // 'text' or 'checklist'
  final List<ChecklistItem> checklistItems;
  final String color;
  final bool isPinned;
  final bool isPinnedToNotifications;
  final bool isLocked;
  final String? lockPassword;
  final String? trashedAt;
  final DateTime? reminderAt;
  final List<Collaborator> collaborators;
  final String? createdBy;
  final DateTime? createdDate;
  final DateTime? updatedDate;
  final List<String> tags;
  final bool titleSetManually;

  Note({
    this.id,
    this.title = '',
    this.content = '',
    this.type = 'text',
    this.checklistItems = const [],
    this.color = 'yellow',
    this.isPinned = false,
    this.isPinnedToNotifications = false,
    this.isLocked = false,
    this.lockPassword,
    this.trashedAt,
    this.reminderAt,
    this.collaborators = const [],
    this.createdBy,
    this.createdDate,
    this.updatedDate,
    this.tags = const [],
    this.titleSetManually = false,
  });

  factory Note.fromSupabase(Map<String, dynamic> data) {
    return Note(
      id: data['id'],
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      type: data['type'] ?? 'text',
      checklistItems:
          (data['checklist_items'] as List<dynamic>?)
              ?.map(
                (item) =>
                    ChecklistItem.fromMap(Map<String, dynamic>.from(item)),
              )
              .toList() ??
          [],
      color: data['color'] ?? 'yellow',
      isPinned: data['is_pinned'] ?? false,
      isPinnedToNotifications: data['is_pinned_to_notifications'] ?? false,
      isLocked: data['is_locked'] ?? false,
      lockPassword: data['lock_password'],
      trashedAt: data['trashed_at'],
      reminderAt: data['reminder_at'] != null
          ? DateTime.parse(data['reminder_at'])
          : null,
      collaborators:
          (data['collaborators'] as List<dynamic>?)
              ?.map((c) => Collaborator.fromMap(Map<String, dynamic>.from(c)))
              .toList() ??
          [],
      createdBy: data['user_id'] ?? data['created_by'],
      createdDate: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
      updatedDate: data['updated_at'] != null
          ? DateTime.parse(data['updated_at'])
          : null,
      tags: data['tags'] != null
          ? List<String>.from(data['tags'])
          : [],
      titleSetManually: data['title_set_manually'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'checklistItems': checklistItems.map((item) => item.toMap()).toList(),
      'color': color,
      'isPinned': isPinned,
      'isPinnedToNotifications': isPinnedToNotifications,
      'isLocked': isLocked,
      'lockPassword': lockPassword,
      'trashedAt': trashedAt,
      'reminderAt': reminderAt?.toIso8601String(),
      'collaborators': collaborators.map((c) => c.toMap()).toList(),
      'created_by': createdBy,
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
      'tags': tags,
      'titleSetManually': titleSetManually,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'title': title,
      'content': content,
      'type': type,
      'checklist_items': checklistItems.map((item) => item.toMap()).toList(),
      'color': color,
      'is_pinned': isPinned,
      'is_pinned_to_notifications': isPinnedToNotifications,
      'is_locked': isLocked,
      'lock_password': lockPassword,
      'trashed_at': trashedAt,
      'reminder_at': reminderAt?.toIso8601String(),
      'collaborators': collaborators.map((c) => c.toMap()).toList(),
      'created_by': createdBy,
      'tags': tags,
      'title_set_manually': titleSetManually,
    };
  }

  Note copyWith({
    String? id,
    String? title,
    String? content,
    String? type,
    List<ChecklistItem>? checklistItems,
    String? color,
    bool? isPinned,
    bool? isPinnedToNotifications,
    bool? isLocked,
    String? lockPassword,
    String? trashedAt,
    DateTime? reminderAt,
    List<Collaborator>? collaborators,
    String? createdBy,
    DateTime? createdDate,
    DateTime? updatedDate,
    List<String>? tags,
    bool? titleSetManually,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      checklistItems: checklistItems ?? this.checklistItems,
      color: color ?? this.color,
      isPinned: isPinned ?? this.isPinned,
      isPinnedToNotifications:
          isPinnedToNotifications ?? this.isPinnedToNotifications,
      isLocked: isLocked ?? this.isLocked,
      lockPassword: lockPassword ?? this.lockPassword,
      trashedAt: trashedAt ?? this.trashedAt,
      reminderAt: reminderAt ?? this.reminderAt,
      collaborators: collaborators ?? this.collaborators,
      createdBy: createdBy ?? this.createdBy,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
      tags: tags ?? this.tags,
      titleSetManually: titleSetManually ?? this.titleSetManually,
    );
  }
}

/// Checklist Item Model
class ChecklistItem {
  final String id;
  final String text;
  final bool checked;

  ChecklistItem({required this.id, this.text = '', this.checked = false});

  factory ChecklistItem.fromMap(Map<String, dynamic> map) {
    return ChecklistItem(
      id: map['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      text: map['text'] ?? '',
      checked: map['checked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'text': text, 'checked': checked};
  }

  ChecklistItem copyWith({String? id, String? text, bool? checked}) {
    return ChecklistItem(
      id: id ?? this.id,
      text: text ?? this.text,
      checked: checked ?? this.checked,
    );
  }
}

/// Collaborator Model
class Collaborator {
  final String email;
  final bool accepted;
  final bool canEdit; // true = editor, false = view only

  Collaborator({
    required this.email,
    this.accepted = false,
    this.canEdit = true, // default to editor
  });

  factory Collaborator.fromMap(Map<String, dynamic> map) {
    return Collaborator(
      email: map['email'] ?? '',
      accepted: map['accepted'] ?? false,
      canEdit: map['canEdit'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {'email': email, 'accepted': accepted, 'canEdit': canEdit};
  }

  Collaborator copyWith({String? email, bool? accepted, bool? canEdit}) {
    return Collaborator(
      email: email ?? this.email,
      accepted: accepted ?? this.accepted,
      canEdit: canEdit ?? this.canEdit,
    );
  }
}

/// Tag Model
class Tag {
  final String? id;
  final String name;
  final String type;
  final String color;
  final int order;

  Tag({
    this.id,
    required this.name,
    this.type = 'text',
    this.color = '#10B981',
    this.order = 0,
  });

  factory Tag.fromSupabase(Map<String, dynamic> data) {
    return Tag(
      id: data['id'],
      name: data['name'] ?? '',
      type: data['type'] ?? 'text',
      color: data['color'] ?? '#10B981',
      order: data['order'] ?? 0,
    );
  }
}

/// Notes Service - Supabase CRUD operations
class NotesService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _auth;
  late final LocalNotesService _localNotesService;

  NotesService(this._auth) {
    _localNotesService = LocalNotesService(LocalDatabaseService.instance, _auth);
  }

  String get _userId => _auth.currentUserId ?? '';
  String get _userEmail => _auth.currentUserEmail ?? '';

  void _triggerBackgroundSync() {
    if (!kIsWeb && _userId.isNotEmpty) {
      SyncEngine(LocalDatabaseService.instance, _auth).sync().catchError((e) {
        debugPrint('Background sync error: $e');
      });
    }
  }

  // ===========================================================
  // Notes CRUD
  // ===========================================================

  /// Get all notes for current user
  Future<List<Note>> getNotes() async {
    if (!kIsWeb) {
      return await _localNotesService.getNotes();
    }

    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('user_id', _userId)
          .order('updated_at', ascending: false);

      return (response as List).map((row) => Note.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Error getting notes: $e');
      return [];
    }
  }

  /// Get active (non-trashed) notes (owned + shared)
  Future<List<Note>> getActiveNotes() async {
    if (!kIsWeb) {
      return await _localNotesService.getActiveNotes();
    }

    try {
      // Get own notes
      final ownResponse = await _client
          .from('notes')
          .select()
          .eq('user_id', _userId)
          .isFilter('trashed_at', null)
          .order('updated_at', ascending: false);

      final ownNotes =
          (ownResponse as List).map((row) => Note.fromSupabase(row)).toList();

      // Get shared notes (accepted collaborations)
      final sharedNotes = await getSharedNotes();

      // Merge, avoiding duplicates
      final ownNoteIds = ownNotes.map((n) => n.id).toSet();
      for (final note in sharedNotes) {
        if (!ownNoteIds.contains(note.id)) {
          ownNotes.add(note);
        }
      }

      // Sort by updated date
      ownNotes.sort((a, b) =>
          (b.updatedDate ?? DateTime(0)).compareTo(a.updatedDate ?? DateTime(0)));

      return ownNotes;
    } catch (e) {
      debugPrint('Error getting active notes: $e');
      return [];
    }
  }


  /// Get trashed notes
  Future<List<Note>> getTrashedNotes() async {
    if (!kIsWeb) {
      return await _localNotesService.getTrashedNotes();
    }

    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('user_id', _userId)
          .not('trashed_at', 'is', null)
          .order('updated_at', ascending: false);

      return (response as List).map((row) => Note.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Error getting trashed notes: $e');
      return [];
    }
  }

  /// Get a single note by ID
  Future<Note?> getNote(String noteId) async {
    if (!kIsWeb) {
      return await _localNotesService.getNote(noteId);
    }

    try {
      final response = await _client
          .from('notes')
          .select()
          .eq('id', noteId)
          .single();
      return Note.fromSupabase(response);
    } catch (e) {
      debugPrint('Error getting note: $e');
      return null;
    }
  }

  /// Create a new note
  Future<Note?> createNote(Note note) async {
    if (!kIsWeb) {
      final created = await _localNotesService.createNote(note);
      _triggerBackgroundSync();
      return created;
    }

    try {
      final data = note.toSupabase();
      data['user_id'] = _userId;
      data['created_at'] = DateTime.now().toUtc().toIso8601String();
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      final response = await _client
          .from('notes')
          .insert(data)
          .select()
          .single();

      return Note.fromSupabase(response);
    } catch (e) {
      debugPrint('Error creating note: $e');
      rethrow;
    }
  }

  /// Update an existing note
  Future<void> updateNote(String noteId, Map<String, dynamic> updates) async {
    if (!kIsWeb) {
      await _localNotesService.updateNote(noteId, updates);
      _triggerBackgroundSync();
      return;
    }

    try {
      // Convert camelCase to snake_case for Supabase
      final supabaseUpdates = <String, dynamic>{};
      updates.forEach((key, value) {
        final snakeKey = _toSnakeCase(key);
        supabaseUpdates[snakeKey] = value;
      });
      supabaseUpdates['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _client.from('notes').update(supabaseUpdates).eq('id', noteId);
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  /// Delete a note permanently
  Future<void> deleteNote(String noteId) async {
    if (!kIsWeb) {
      await _localNotesService.deleteNote(noteId);
      _triggerBackgroundSync();
      return;
    }

    try {
      await _client.from('notes').delete().eq('id', noteId);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  /// Move note to trash
  Future<void> trashNote(String noteId) async {
    if (!kIsWeb) {
      await _localNotesService.trashNote(noteId);
      _triggerBackgroundSync();
      return;
    }
    await updateNote(noteId, {'trashedAt': DateTime.now().toIso8601String()});
  }

  /// Restore note from trash
  Future<void> restoreNote(String noteId) async {
    if (!kIsWeb) {
      await _localNotesService.restoreNote(noteId);
      _triggerBackgroundSync();
      return;
    }

    try {
      await _client
          .from('notes')
          .update({
            'trashed_at': null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', noteId);
    } catch (e) {
      debugPrint('Error restoring note: $e');
      rethrow;
    }
  }

  /// Empty trash (delete all trashed notes)
  Future<void> emptyTrash() async {
    if (!kIsWeb) {
      await _localNotesService.emptyTrash();
      _triggerBackgroundSync();
      return;
    }

    try {
      await _client
          .from('notes')
          .delete()
          .eq('user_id', _userId)
          .not('trashed_at', 'is', null);
    } catch (e) {
      debugPrint('Error emptying trash: $e');
      rethrow;
    }
  }

  // ===========================================================
  // Collaboration (stub - can be implemented later)
  // ===========================================================

  Future<List<Map<String, dynamic>>> getPendingInvites() async {
    try {
      final response = await _client
          .from('collaboration_invites')
          .select()
          .eq('to_email', _userEmail.toLowerCase())
          .eq('status', 'pending');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting pending invites: $e');
      return [];
    }
  }

  Future<void> acceptInvite(String inviteId) async {
    try {
      await _client
          .from('collaboration_invites')
          .update({
            'status': 'accepted',
            'accepted_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', inviteId);
    } catch (e) {
      debugPrint('Error accepting invite: $e');
      rethrow;
    }
  }

  Future<void> rejectInvite(String inviteId) async {
    try {
      await _client
          .from('collaboration_invites')
          .update({
            'status': 'rejected',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', inviteId);
    } catch (e) {
      debugPrint('Error rejecting invite: $e');
      rethrow;
    }
  }

  Future<void> leaveNote(String noteId) async {
    try {
      await _client
          .from('collaboration_invites')
          .update({
            'status': 'rejected',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('note_id', noteId)
          .eq('to_email', _userEmail.toLowerCase());
    } catch (e) {
      debugPrint('Error leaving note: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getRejectedInvites() async {
    try {
      final response = await _client
          .from('collaboration_invites')
          .select()
          .eq('to_email', _userEmail.toLowerCase())
          .eq('status', 'rejected');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting archived invites: $e');
      return [];
    }
  }

  /// Get notes shared with the current user (accepted invites)
  Future<List<Note>> getSharedNotes() async {
    try {
      // Get accepted invite note_ids
      final invites = await _client
          .from('collaboration_invites')
          .select('note_id')
          .eq('to_email', _userEmail.toLowerCase())
          .eq('status', 'accepted');

      final noteIds =
          (invites as List).map((i) => i['note_id'] as String).toList();
      if (noteIds.isEmpty) return [];

      final response = await _client
          .from('notes')
          .select()
          .inFilter('id', noteIds)
          .isFilter('trashed_at', null)
          .order('updated_at', ascending: false);

      return (response as List).map((row) => Note.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Error getting shared notes: $e');
      return [];
    }
  }

  /// Get live invite statuses for a specific note (for the Share dialog)
  Future<List<Map<String, dynamic>>> getInviteStatusesForNote(
    String noteId,
  ) async {
    try {
      final response = await _client
          .from('collaboration_invites')
          .select()
          .eq('note_id', noteId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting invite statuses: $e');
      return [];
    }
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

  // ===========================================================
  // Sharing (stub methods - can be fully implemented later)
  // ===========================================================

  /// Create a share token for a note
  Future<String?> createShareToken(String noteId) async {
    // TODO: Implement proper sharing via shared_notes table
    debugPrint('Share token creation not yet implemented');
    return null;
  }

  // ===========================================================
  // Note Snapshots (read-only shareable copies)
  // ===========================================================

  /// Create a snapshot of a note's current state, or return existing
  /// token if the content hasn't changed since last snapshot.
  Future<String> createNoteSnapshot({
    required String noteId,
    required String title,
    required String content,
    required String noteType,
    required List<ChecklistItem> checklistItems,
    required String color,
  }) async {
    // Build a content hash for deduplication
    final itemsJson = checklistItems.map((i) => '${i.text}:${i.checked}').join('|');
    final hashInput = '$title|$content|$itemsJson';
    // Simple hash using Dart's hashCode (sufficient for dedup)
    final contentHash = hashInput.hashCode.toRadixString(16);

    // Check if a snapshot already exists with the same note_id + content_hash
    try {
      final existing = await _client
          .from('note_snapshots')
          .select('token')
          .eq('note_id', noteId)
          .eq('content_hash', contentHash)
          .maybeSingle();

      if (existing != null) {
        return existing['token'] as String;
      }
    } catch (e) {
      debugPrint('Error checking existing snapshot: $e');
    }

    // Create new snapshot
    final response = await _client
        .from('note_snapshots')
        .insert({
          'note_id': noteId,
          'content_hash': contentHash,
          'title': title,
          'content': content,
          'note_type': noteType,
          'checklist_items': checklistItems.map((i) => i.toMap()).toList(),
          'color': _colorNameToInt(color),
          'created_by': _userId,
        })
        .select('token')
        .single();

    return response['token'] as String;
  }

  /// Fetch a snapshot by its public token (no auth required)
  Future<Map<String, dynamic>?> getSnapshot(String token) async {
    try {
      final response = await _client
          .from('note_snapshots')
          .select()
          .eq('token', token)
          .maybeSingle();

      return response;
    } catch (e) {
      debugPrint('Error fetching snapshot: $e');
      return null;
    }
  }

  /// Import a snapshot as a brand-new note for the current user.
  /// Returns the created Note or null on failure.
  Future<Note?> importFromSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final colorIndex = (snapshot['color'] as int?) ?? 0;
      final colorName = _intToColorName(colorIndex);
      final noteType = snapshot['note_type'] ?? 'text';

      // Reconstruct checklist items if applicable
      final rawItems = (snapshot['checklist_items'] as List<dynamic>?) ?? [];
      final checklistItems = rawItems
          .map((item) => ChecklistItem.fromMap(Map<String, dynamic>.from(item)))
          .toList();

      final note = Note(
        title: snapshot['title'] ?? '',
        content: snapshot['content'] ?? '',
        type: noteType,
        checklistItems: checklistItems,
        color: colorName,
      );

      return await createNote(note);
    } catch (e) {
      debugPrint('Error importing from snapshot: $e');
      return null;
    }
  }

  /// Map color name to int index for snapshot storage
  int _colorNameToInt(String colorName) {
    const colorNames = ['yellow', 'orange', 'red', 'pink', 'purple', 'blue', 'teal', 'green'];
    return colorNames.indexOf(colorName).clamp(0, colorNames.length - 1);
  }

  /// Map int index back to color name
  String _intToColorName(int index) {
    const colorNames = ['yellow', 'orange', 'red', 'pink', 'purple', 'blue', 'teal', 'green'];
    return index < colorNames.length ? colorNames[index] : 'yellow';
  }

  /// Claim a shared note by token
  Future<void> claimSharedNote(String shareToken) async {
    // TODO: Implement proper note claiming from shared_notes table
    debugPrint('Shared note claiming not yet implemented');
  }

  /// Send collaboration invite
  Future<void> sendCollaborationInvite({
    required String noteId,
    required String noteTitle,
    required String inviteeEmail,
    bool canEdit = true,
  }) async {
    try {
      await _client.from('collaboration_invites').upsert({
        'note_id': noteId,
        'note_title': noteTitle,
        'note_owner_id': _userId,
        'from_email': _userEmail,
        'to_email': inviteeEmail.toLowerCase(),
        'can_edit': canEdit,
        'status': 'pending',
      }, onConflict: 'note_id, to_email');
      // Email is sent automatically by the database trigger
    } catch (e) {
      debugPrint('Error sending invite: $e');
      rethrow;
    }
  }

  /// Update an existing collaborator's permission
  Future<void> updateCollaboratorPermission(String noteId, String email, bool canEdit) async {
    try {
      await _client
          .from('collaboration_invites')
          .update({'can_edit': canEdit})
          .eq('note_id', noteId)
          .eq('to_email', email.toLowerCase());
    } catch (e) {
      debugPrint('Error updating permission: $e');
      rethrow;
    }
  }

  /// Revoke an invite when removing a collaborator
  Future<void> revokeInvite(String noteId, String email) async {
    try {
      await _client
          .from('collaboration_invites')
          .update({
            'status': 'revoked',
            'rejected_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('note_id', noteId)
          .eq('to_email', email.toLowerCase());
    } catch (e) {
      debugPrint('Error revoking invite: $e');
      rethrow;
    }
  }
}
