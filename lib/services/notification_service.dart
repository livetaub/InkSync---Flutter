import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// NotificationService — Handles "Pin to Notification Bar" feature.
/// Creates persistent, ongoing notifications that deep-link back to a note.
class NotificationService {
  static NotificationService? _instance;
  static NotificationService get instance {
    _instance ??= NotificationService._();
    return _instance!;
  }

  NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Callback for when a notification is tapped
  static void Function(String noteId)? onNotificationTapped;

  /// Generate a deterministic notification ID using FNV-1a hash.
  /// Better distribution than String.hashCode to avoid ID collisions.
  static int _generateNotificationId(String noteId) {
    int hash = 0x811c9dc5;
    for (int i = 0; i < noteId.length; i++) {
      hash ^= noteId.codeUnitAt(i);
      hash = (hash * 0x01000193) & 0x7FFFFFFF;
    }
    return hash;
  }

  /// Initialize the notification system
  Future<void> init() async {
    if (kIsWeb) return; // Notifications are mobile-only

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    debugPrint('NotificationService: Initialized');
  }

  /// Request notification permissions (call during onboarding or first pin)
  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;

    // Android 13+ requires runtime permission
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }

    // iOS
    final iosPlugin = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: false,
        sound: false,
      );
      return granted ?? false;
    }

    return true;
  }

  /// Pin a note to the notification bar.
  /// Uses the note's hashCode as the notification ID for uniqueness.
  Future<void> pinNote({
    required String noteId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

    // Ensure permissions
    final hasPermission = await requestPermissions();
    if (!hasPermission) {
      debugPrint('NotificationService: Permission denied');
      return;
    }

    // Truncate body for notification display
    final snippet = body.length > 200 ? '${body.substring(0, 200)}…' : body;
    final displayTitle = title.isNotEmpty ? title : 'Untitled Note';

    const androidDetails = AndroidNotificationDetails(
      'pinned_notes_silent',
      'Pinned Notes',
      channelDescription: 'Notes pinned to the notification bar for quick access',
      importance: Importance.min,
      priority: Priority.min,
      ongoing: true, // Cannot be swiped away
      autoCancel: false,
      showWhen: false,
      playSound: false,
      enableVibration: false,
      channelShowBadge: false,
      silent: true,
      icon: '@mipmap/ic_launcher',
      styleInformation: BigTextStyleInformation(''),
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: false,
      presentSound: false,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Use FNV-1a hash for stable, collision-resistant notification IDs
    final notificationId = _generateNotificationId(noteId);

    await _plugin.show(
      notificationId,
      '📌 $displayTitle',
      snippet,
      details,
      payload: jsonEncode({'noteId': noteId}),
    );

    debugPrint('NotificationService: Pinned note $noteId (notif #$notificationId)');
  }

  /// Unpin a note from the notification bar
  Future<void> unpinNote(String noteId) async {
    if (kIsWeb) return;

    final notificationId = _generateNotificationId(noteId);
    await _plugin.cancel(notificationId);
    debugPrint('NotificationService: Unpinned note $noteId');
  }

  /// Check if a note is currently pinned
  Future<bool> isNotePinned(String noteId) async {
    if (kIsWeb) return false;

    final active = await _plugin.getActiveNotifications();
    final notificationId = _generateNotificationId(noteId);
    return active.any((n) => n.id == notificationId);
  }

  /// Handle notification tap — extract noteId and invoke callback
  static void _onNotificationResponse(NotificationResponse response) {
    if (response.payload == null) return;

    try {
      final data = jsonDecode(response.payload!);
      final noteId = data['noteId'] as String?;
      if (noteId != null && onNotificationTapped != null) {
        onNotificationTapped!(noteId);
      }
    } catch (e) {
      debugPrint('NotificationService: Failed to parse payload — $e');
    }
  }

  /// Cancel all pinned notifications
  Future<void> cancelAll() async {
    if (kIsWeb) return;
    await _plugin.cancelAll();
  }
}
