/// Model representing a Quick Note message (message-to-self feature).
class QuickNote {
  final String? id;
  final String userId;
  final String type; // 'text', 'voice', 'image', 'pdf'
  final String? content;
  final String? mediaUrl;
  final String? fileName;
  final int? durationSeconds;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int syncStatus; // 0=synced, 1=pending_create, 2=pending_update, 3=pending_delete

  QuickNote({
    this.id,
    required this.userId,
    this.type = 'text',
    this.content,
    this.mediaUrl,
    this.fileName,
    this.durationSeconds,
    this.isPinned = false,
    DateTime? createdAt,
    this.updatedAt,
    this.syncStatus = 0,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Create a [QuickNote] instance from a Map (Supabase DB row or JSON).
  factory QuickNote.fromMap(Map<String, dynamic> map) {
    return QuickNote(
      id: map['id'] as String?,
      userId: (map['user_id'] ?? map['userId']) as String? ?? '',
      type: map['type'] as String? ?? 'text',
      content: map['content'] as String?,
      mediaUrl: (map['media_url'] ?? map['mediaUrl']) as String?,
      fileName: (map['file_name'] ?? map['fileName']) as String?,
      durationSeconds: map['duration_seconds'] != null
          ? (map['duration_seconds'] as num).toInt()
          : (map['durationSeconds'] != null
              ? (map['durationSeconds'] as num).toInt()
              : null),
      isPinned: (map['is_pinned'] ?? map['isPinned']) == true || (map['is_pinned'] == 1),
      createdAt: _parseDateTime(map['created_at'] ?? map['createdAt']) ?? DateTime.now(),
      updatedAt: _parseDateTime(map['updated_at'] ?? map['updatedAt']),
      syncStatus: (map['sync_status'] as num?)?.toInt() ?? 0,
    );
  }

  /// Helper to safely parse DateTime from String or DateTime.
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  /// Convert this [QuickNote] instance to a Map for SQLite operations.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type,
      'content': content,
      'media_url': mediaUrl,
      'file_name': fileName,
      'duration_seconds': durationSeconds,
      'is_pinned': isPinned ? 1 : 0, // SQLite boolean
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
      'sync_status': syncStatus,
    };
  }

  /// Convert this [QuickNote] instance to a Map for Supabase operations.
  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'type': type,
      if (content != null) 'content': content,
      if (mediaUrl != null) 'media_url': mediaUrl,
      if (fileName != null) 'file_name': fileName,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      'is_pinned': isPinned,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': (updatedAt ?? createdAt).toUtc().toIso8601String(),
    };
  }

  /// Create a copy of this [QuickNote] with updated fields.
  QuickNote copyWith({
    String? id,
    String? userId,
    String? type,
    String? content,
    String? mediaUrl,
    String? fileName,
    int? durationSeconds,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return QuickNote(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      content: content ?? this.content,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      fileName: fileName ?? this.fileName,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
