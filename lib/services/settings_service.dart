import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'sync_engine.dart';

/// UserSettings Model
class UserSettings {
  final String? id;
  final String viewMode;
  final String sortBy;
  final bool darkMode;
  final bool notificationsEnabled;
  final bool isPremium;
  final DateTime? lastSyncAt;
  final DateTime? createdDate;
  final DateTime? updatedDate;

  UserSettings({
    this.id,
    this.viewMode = 'list',
    this.sortBy = 'modified',
    this.darkMode = false,
    this.notificationsEnabled = true,
    this.isPremium = false,
    this.lastSyncAt,
    this.createdDate,
    this.updatedDate,
  });

  factory UserSettings.fromSupabase(Map<String, dynamic> data) {
    return UserSettings(
      id: data['id'],
      viewMode: data['sort_order'] ?? 'list', // Mapped from schema
      sortBy: data['sort_order'] ?? 'modified',
      darkMode: false, // Not in schema, use default
      notificationsEnabled: data['haptic_enabled'] ?? true,
      isPremium: data['is_premium'] ?? false,
      lastSyncAt: null,
      createdDate: data['created_at'] != null
          ? DateTime.parse(data['created_at'])
          : null,
      updatedDate: null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'viewMode': viewMode,
      'sortBy': sortBy,
      'darkMode': darkMode,
      'notificationsEnabled': notificationsEnabled,
      'isPremium': isPremium,
      'lastSyncAt': lastSyncAt?.toIso8601String(),
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
    };
  }

  UserSettings copyWith({
    String? id,
    String? viewMode,
    String? sortBy,
    bool? darkMode,
    bool? notificationsEnabled,
    bool? isPremium,
    DateTime? lastSyncAt,
    DateTime? createdDate,
    DateTime? updatedDate,
  }) {
    return UserSettings(
      id: id ?? this.id,
      viewMode: viewMode ?? this.viewMode,
      sortBy: sortBy ?? this.sortBy,
      darkMode: darkMode ?? this.darkMode,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      isPremium: isPremium ?? this.isPremium,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
    );
  }
}

/// Settings Service - Supabase/SQLite implementation
class SettingsService {
  final SupabaseClient _client = Supabase.instance.client;
  final AuthService _auth;

  SettingsService(this._auth);

  String get _userId => _auth.currentUserId ?? '';

  /// Get user settings
  Future<UserSettings> getSettings() async {
    if (!kIsWeb) {
      final local = await LocalDatabaseService.instance.getUserSettings(_userId);
      if (local != null) {
        return UserSettings(
          id: local['id'] as String?,
          viewMode: local['sort_order'] ?? 'list',
          sortBy: local['sort_order'] ?? 'modified',
          darkMode: false,
          notificationsEnabled: (local['haptic_enabled'] as int?) == 1,
          isPremium: (local['is_premium'] as int?) == 1,
        );
      }
      return UserSettings();
    }

    if (_userId.isEmpty) return UserSettings();

    try {
      final response = await _client
          .from('user_settings')
          .select()
          .eq('user_id', _userId)
          .maybeSingle();

      if (response != null) {
        return UserSettings.fromSupabase(response);
      }

      // Create default settings if none exist
      await _createDefaultSettings();
      return UserSettings();
    } catch (e) {
      debugPrint('Error getting settings: $e');
      return UserSettings();
    }
  }

  /// Create default settings for user
  Future<void> _createDefaultSettings() async {
    if (_userId.isEmpty) return;

    try {
      await _client.from('user_settings').insert({
        'user_id': _userId,
        'sort_order': 'updatedDate',
        'sort_ascending': false,
        'default_color': '#10B981',
        'haptic_enabled': true,
        'is_premium': false,
      });
    } catch (e) {
      // May already exist due to trigger
      debugPrint('Note: Settings may already exist: $e');
    }
  }

  /// Update specific setting
  Future<void> updateSetting(String key, dynamic value) async {
    if (!kIsWeb) {
      final snakeKey = key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );
      var dbValue = value;
      if (value is bool) {
        dbValue = value ? 1 : 0;
      }

      final db = await LocalDatabaseService.instance.database;
      await db.update(
        'user_settings',
        {
          snakeKey: dbValue,
          'sync_status': SyncStatus.pendingUpdate,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: _userId.isNotEmpty ? 'user_id = ?' : '1=1',
        whereArgs: _userId.isNotEmpty ? [_userId] : null,
      );

      if (_userId.isNotEmpty) {
        SyncEngine(LocalDatabaseService.instance, _auth).sync().catchError((e) {
          debugPrint('Background settings sync error: $e');
        });
      }
      return;
    }

    if (_userId.isEmpty) return;

    try {
      // Map camelCase keys to snake_case
      final snakeKey = key.replaceAllMapped(
        RegExp(r'[A-Z]'),
        (m) => '_${m.group(0)!.toLowerCase()}',
      );

      await _client
          .from('user_settings')
          .update({snakeKey: value})
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('Error updating setting: $e');
    }
  }

  /// Update last sync time (stored locally since not in schema)
  Future<void> updateLastSync() async {
    // This is a no-op for now - sync time can be tracked locally
  }

  /// Upgrade to premium
  Future<void> upgradeToPremium() async {
    await updateSetting('isPremium', true);
  }

  /// Save full settings
  Future<void> saveSettings(UserSettings settings) async {
    if (!kIsWeb) {
      final db = await LocalDatabaseService.instance.database;
      await db.insert(
        'user_settings',
        {
          'user_id': _userId.isEmpty ? null : _userId,
          'sort_order': settings.sortBy,
          'is_premium': settings.isPremium ? 1 : 0,
          'haptic_enabled': settings.notificationsEnabled ? 1 : 0,
          'sync_status': SyncStatus.pendingUpdate,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      if (_userId.isNotEmpty) {
        SyncEngine(LocalDatabaseService.instance, _auth).sync().catchError((e) {
          debugPrint('Background settings sync error: $e');
        });
      }
      return;
    }

    if (_userId.isEmpty) return;

    try {
      await _client.from('user_settings').upsert({
        'user_id': _userId,
        'sort_order': settings.sortBy,
        'is_premium': settings.isPremium,
        'haptic_enabled': settings.notificationsEnabled,
      });
    } catch (e) {
      debugPrint('Error saving settings: $e');
    }
  }

  /// Stream of settings (uses polling since Supabase realtime requires setup)
  Stream<UserSettings> getSettingsStream() {
    // Return a stream that emits current settings
    // For real-time updates, you'd need Supabase Realtime configured
    return Stream.periodic(const Duration(seconds: 30), (_) async {
      return await getSettings();
    }).asyncMap((future) => future);
  }
}
