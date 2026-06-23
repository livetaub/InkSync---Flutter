import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paywall_variant.dart';
import 'local_database_service.dart';

/// PaywallService — Manages paywall variants, A/B test assignments,
/// and analytics event tracking.
///
/// Single source of truth for:
/// - Paywall copy & pricing (fetched from `paywall_variants` table)
/// - Sticky A/B test assignments (stored in `paywall_assignments` + local cache)
/// - Conversion analytics (tracked in `paywall_events` table)
class PaywallService {
  static final PaywallService instance = PaywallService._();
  PaywallService._();

  PaywallVariant? _cachedVariant;
  bool _initialized = false;

  /// Get the current platform string for analytics
  String get _platform {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.android:
        return 'android';
      default:
        return 'unknown';
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Variant Fetching & Assignment
  // ═══════════════════════════════════════════════════════════════

  /// Get the user's assigned variant.
  ///
  /// Priority:
  /// 1. In-memory cache (instant, if not fallback)
  /// 2. Try online fetch first (if connected)
  /// 3. Try local SQLite cache (offline support)
  /// 4. Hardcoded fallback (if everything fails)
  Future<PaywallVariant> getVariant() async {
    // 1. In-memory cache
    if (_cachedVariant != null && _cachedVariant!.id != 'fallback') {
      return _cachedVariant!;
    }

    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    // 2. Try online fetch first (if connected)
    try {
      // Check if authenticated
      if (userId != null) {
        final assignment = await supabase
            .from('paywall_assignments')
            .select('variant_id')
            .eq('user_id', userId)
            .maybeSingle();

        if (assignment != null && assignment['variant_id'] != null) {
          final variant = await _fetchVariantById(assignment['variant_id']);
          if (variant != null) {
            _cachedVariant = variant;
            await _cacheVariantLocally(variant);
            return variant;
          }
        }
      }

      // No assignment or guest — fetch all active variants and assign
      final variants = await _fetchActiveVariants();
      if (variants.isNotEmpty) {
        final selected = _weightedRandomPick(variants);
        _cachedVariant = selected;

        if (userId != null) {
          await _saveAssignment(userId, selected.id);
        }
        await _cacheVariantLocally(selected);
        return selected;
      }
    } catch (e) {
      debugPrint('PaywallService: Online fetch failed, using local cache: $e');
    }

    // 3. Try local SQLite cache (fallback for offline)
    final localVariant = await _getLocalCachedVariant();
    if (localVariant != null && localVariant.id != 'fallback') {
      _cachedVariant = localVariant;
      // Trigger background update if logged in
      if (userId != null) {
        _refreshFromServer(userId);
      }
      return localVariant;
    }

    // 4. Hardcoded fallback
    _cachedVariant = PaywallVariant.fallback;
    return _cachedVariant!;
  }

  /// Get plan limits for feature enforcement (note limits, AI credits).
  /// Used by note_edit_screen to check limits.
  Future<PlanLimits> getPlanLimits(String accountType) async {
    try {
      // 1. Try to fetch live from global_pricing table
      final response = await Supabase.instance.client
          .from('global_pricing')
          .select('notes_limit, ai_credits_limit')
          .eq('plan_id', accountType)
          .maybeSingle();

      if (response != null) {
        final limits = PlanLimits(
          notesLimit: response['notes_limit'] as int? ?? (accountType == 'premium' ? 250 : 75),
          aiCredits: response['ai_credits_limit'] as int? ?? (accountType == 'premium' ? 100 : 0),
        );
        // Cache locally
        await _cachePlanLimitsLocally(accountType, limits);
        return limits;
      }
    } catch (e) {
      debugPrint('PaywallService: Error fetching global plan limits: $e');
    }

    // 2. Try to load from local cache
    final cached = await _getLocalCachedPlanLimits(accountType);
    if (cached != null) return cached;

    // 3. Fallback defaults
    return PlanLimits(
      notesLimit: accountType == 'premium' ? 250 : 75,
      aiCredits: accountType == 'premium' ? 100 : 0,
    );
  }

  /// Force refresh the variant from the server.
  /// Call after user signs in or changes account.
  Future<void> refresh() async {
    _cachedVariant = null;
    _initialized = false;
    await getVariant();
  }

  /// Clear all cached data (call on logout).
  Future<void> clearCache() async {
    _cachedVariant = null;
    _initialized = false;
    try {
      if (!kIsWeb) {
        final db = await LocalDatabaseService.instance.database;
        await db.delete('sync_meta',
            where: 'key IN (?, ?)',
            whereArgs: ['paywall_variant', 'paywall_variant_id']);
      }
    } catch (e) {
      debugPrint('PaywallService: Error clearing cache: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Analytics Event Tracking
  // ═══════════════════════════════════════════════════════════════

  /// Track a paywall analytics event.
  ///
  /// Event types:
  /// - `paywall_viewed` — User opened the paywall screen
  /// - `paywall_dismissed` — User closed without purchasing
  /// - `cta_clicked` — User tapped a CTA button
  /// - `checkout_started` — Checkout flow initiated
  /// - `checkout_completed` — Purchase successful
  /// - `subscription_active` — Subscription confirmed active
  Future<void> trackEvent(
    String eventType, {
    String? plan,
    String? period,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      final variantId = _cachedVariant?.id;
      if (variantId == 'fallback') return; // Don't track fallback variant

      await supabase.from('paywall_events').insert({
        'user_id': userId, // Can be null for guest users
        'variant_id': variantId,
        'event_type': eventType,
        'platform': _platform,
        'plan': plan,
        'period': period,
        'metadata': metadata ?? {},
      });

      debugPrint('PaywallService: Tracked event: $eventType '
          '(plan=$plan, period=$period, variant=$variantId, userId=$userId)');
    } catch (e) {
      // Non-critical — don't block UX for analytics failures
      debugPrint('PaywallService: Failed to track event $eventType: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Guest → Authenticated Migration
  // ═══════════════════════════════════════════════════════════════

  /// Migrate a guest's locally cached assignment to Supabase.
  /// Call after the user signs up / logs in.
  Future<void> migrateGuestAssignment(String userId) async {
    try {
      if (kIsWeb) return; // Web guests don't have local DB

      final db = await LocalDatabaseService.instance.database;
      final cached = await db.query('sync_meta',
          where: 'key = ?', whereArgs: ['paywall_variant_id']);

      if (cached.isNotEmpty) {
        final variantId = cached.first['value'] as String;
        if (variantId != 'fallback') {
          await _saveAssignment(userId, variantId);
          debugPrint(
              'PaywallService: Migrated guest assignment to user $userId');
        }
      }
    } catch (e) {
      debugPrint('PaywallService: Error migrating guest assignment: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // Private Helpers
  // ═══════════════════════════════════════════════════════════════

  /// Fetch a single variant by ID from Supabase
  Future<PaywallVariant?> _fetchVariantById(String variantId) async {
    try {
      final data = await Supabase.instance.client
          .from('paywall_variants')
          .select()
          .eq('id', variantId)
          .eq('is_active', true)
          .maybeSingle();

      if (data == null) return null;
      return PaywallVariant.fromJson(data);
    } catch (e) {
      debugPrint('PaywallService: Error fetching variant by ID: $e');
      return null;
    }
  }

  /// Fetch all active variants from Supabase
  Future<List<PaywallVariant>> _fetchActiveVariants() async {
    final data = await Supabase.instance.client
        .from('paywall_variants')
        .select()
        .eq('is_active', true);

    return (data as List)
        .map((row) => PaywallVariant.fromJson(row))
        .toList();
  }

  /// Weighted random pick from a list of variants
  PaywallVariant _weightedRandomPick(List<PaywallVariant> variants) {
    if (variants.length == 1) return variants.first;

    final totalWeight =
        variants.fold<int>(0, (sum, v) => sum + v.trafficWeight);
    final random = Random().nextInt(totalWeight);

    int cumulative = 0;
    for (final variant in variants) {
      cumulative += variant.trafficWeight;
      if (random < cumulative) return variant;
    }

    return variants.last;
  }

  /// Save assignment to Supabase
  Future<void> _saveAssignment(String userId, String variantId) async {
    try {
      await Supabase.instance.client.from('paywall_assignments').upsert({
        'user_id': userId,
        'variant_id': variantId,
        'assigned_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      debugPrint('PaywallService: Error saving assignment: $e');
    }
  }

  /// Cache variant to local SQLite (for offline access + guests)
  Future<void> _cacheVariantLocally(PaywallVariant variant) async {
    try {
      if (kIsWeb) return; // Web doesn't use local SQLite

      final db = await LocalDatabaseService.instance.database;
      final json = jsonEncode(variant.toJson());

      await db.insert(
        'sync_meta',
        {'key': 'paywall_variant', 'value': json},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        'sync_meta',
        {'key': 'paywall_variant_id', 'value': variant.id},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('PaywallService: Error caching variant locally: $e');
    }
  }

  /// Read cached variant from local SQLite
  Future<PaywallVariant?> _getLocalCachedVariant() async {
    try {
      if (kIsWeb) return null;

      final db = await LocalDatabaseService.instance.database;
      final result = await db.query('sync_meta',
          where: 'key = ?', whereArgs: ['paywall_variant']);

      if (result.isEmpty) return null;

      final json = jsonDecode(result.first['value'] as String);
      return PaywallVariant.fromJson(json as Map<String, dynamic>);
    } catch (e) {
      debugPrint('PaywallService: Error reading local cache: $e');
      return null;
    }
  }

  /// Background refresh from server (updates cache without blocking UI)
  Future<void> _refreshFromServer(String userId) async {
    try {
      final assignment = await Supabase.instance.client
          .from('paywall_assignments')
          .select('variant_id')
          .eq('user_id', userId)
          .maybeSingle();

      if (assignment != null && assignment['variant_id'] != null) {
        final variant = await _fetchVariantById(assignment['variant_id']);
        if (variant != null) {
          _cachedVariant = variant;
          await _cacheVariantLocally(variant);
        }
      }
    } catch (e) {
      debugPrint('PaywallService: Background refresh failed: $e');
    }
  }

  Future<void> _cachePlanLimitsLocally(String accountType, PlanLimits limits) async {
    try {
      if (kIsWeb) return;
      final db = await LocalDatabaseService.instance.database;
      final data = jsonEncode({
        'notes_limit': limits.notesLimit,
        'ai_credits': limits.aiCredits,
      });
      await db.insert(
        'sync_meta',
        {'key': 'plan_limits_$accountType', 'value': data},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      debugPrint('PaywallService: Error caching limits locally: $e');
    }
  }

  Future<PlanLimits?> _getLocalCachedPlanLimits(String accountType) async {
    try {
      if (kIsWeb) return null;
      final db = await LocalDatabaseService.instance.database;
      final rows = await db.query(
        'sync_meta',
        where: 'key = ?',
        whereArgs: ['plan_limits_$accountType'],
      );
      if (rows.isNotEmpty) {
        final data = jsonDecode(rows.first['value'] as String);
        return PlanLimits(
          notesLimit: data['notes_limit'] as int? ?? (accountType == 'premium' ? 250 : 75),
          aiCredits: data['ai_credits'] as int? ?? (accountType == 'premium' ? 100 : 0),
        );
      }
    } catch (e) {
      debugPrint('PaywallService: Error reading local cached limits: $e');
    }
    return null;
  }
}
