import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'notes_service.dart'; // Import Tag model
export 'notes_service.dart' show Tag; // Export Tag for other files

/// Tag Service - manages user tags using Supabase
class TagService {
  final AuthService _authService;
  final SupabaseClient _client = Supabase.instance.client;

  TagService(this._authService);

  String? get _userId => _authService.currentUserId;

  /// Get all tags ordered by position
  Future<List<Tag>> getTags() async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('tags')
          .select()
          .eq('user_id', _userId!)
          .order('order', ascending: true);

      return (response as List).map((row) => Tag.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Error getting tags: $e');
      return [];
    }
  }

  /// Get tags by type
  Future<List<Tag>> getTagsByType(String type) async {
    if (_userId == null) return [];

    try {
      final response = await _client
          .from('tags')
          .select()
          .eq('user_id', _userId!)
          .eq('type', type)
          .order('order', ascending: true);

      return (response as List).map((row) => Tag.fromSupabase(row)).toList();
    } catch (e) {
      debugPrint('Error getting tags by type: $e');
      return [];
    }
  }

  /// Create a new tag
  Future<String?> createTag(String name, {String type = 'text'}) async {
    if (_userId == null) return null;

    try {
      // Get current max order for this type
      final tags = await getTagsByType(type);
      final maxOrder = tags.isEmpty
          ? 0
          : tags.map((t) => t.order).reduce((a, b) => a > b ? a : b);

      final response = await _client
          .from('tags')
          .insert({
            'user_id': _userId,
            'name': name,
            'type': type,
            'order': maxOrder + 1,
            'color': '#10B981',
          })
          .select()
          .single();

      return response['id'];
    } catch (e) {
      debugPrint('Error creating tag: $e');
      return null;
    }
  }

  /// Create default tags for new users
  Future<void> createDefaultTags() async {
    if (_userId == null) return;

    try {
      final existingTags = await getTags();
      if (existingTags.isNotEmpty) return; // Already has tags

      // Default note categories
      await createTag('Personal', type: 'text');
      await createTag('Work', type: 'text');

      // Default checklist categories
      await createTag('To Do', type: 'checklist');
      await createTag('Grocery List', type: 'checklist');
    } catch (e) {
      debugPrint('Error creating default tags: $e');
    }
  }

  /// Update tag
  Future<void> updateTag(
    String tagId, {
    String? name,
    String? color,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (color != null) updates['color'] = color;

      if (updates.isNotEmpty) {
        await _client.from('tags').update(updates).eq('id', tagId);
      }
    } catch (e) {
      debugPrint('Error updating tag: $e');
    }
  }

  /// Delete tag (notes will need to have this tag removed from their array)
  Future<void> deleteTag(String tagId) async {
    try {
      // Note: We need an RPC or a manual fetch-and-update to remove a tag from the text[] array
      // For now, delete the tag from the tags table
      await _client.from('tags').delete().eq('id', tagId);
    } catch (e) {
      debugPrint('Error deleting tag: $e');
    }
  }

  /// Get tag by ID
  Future<Tag?> getTag(String tagId) async {
    try {
      final response = await _client
          .from('tags')
          .select()
          .eq('id', tagId)
          .single();

      return Tag.fromSupabase(response);
    } catch (e) {
      debugPrint('Error getting tag: $e');
      return null;
    }
  }

  /// Reorder tags
  Future<void> reorderTags(List<Tag> tags) async {
    if (_userId == null) return;

    try {
      for (int i = 0; i < tags.length; i++) {
        final tag = tags[i];
        if (tag.id != null) {
          await _client
              .from('tags')
              .update({'order': i})
              .eq('id', tag.id!);
        }
      }
    } catch (e) {
      debugPrint('Error reordering tags: $e');
    }
  }
}
