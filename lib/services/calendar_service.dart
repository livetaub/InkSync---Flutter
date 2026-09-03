import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'local_database_service.dart';
import 'sync_engine.dart';
import '../models/calendar_event.dart';

class CalendarService {
  final AuthService _auth;
  CalendarService(this._auth);
  
  String get _userId => _auth.currentUserId ?? '';
  SupabaseClient get _client => Supabase.instance.client;

  // Trigger sync on mobile
  void _triggerSync() {
    if (!kIsWeb) {
      SyncEngine(LocalDatabaseService.instance, _auth).sync().catchError((e) {
        debugPrint('CalendarService sync error: $e');
      });
    }
  }

  // Convert SQLite row to CalendarEvent
  CalendarEvent _eventFromSqlite(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      noteBody: map['note_body'],
      eventDate: DateTime.parse(map['event_date']),
      eventTime: map['event_time'],
      isDone: map['is_done'] == 1,
      reminder: map['reminder'],
      recurrenceType: map['recurrence_type'],
      recurrenceDays: List<int>.from(json.decode(map['recurrence_days'] ?? '[]')),
      completedDates: List<String>.from(json.decode(map['completed_dates'] ?? '[]')),
      overrides: Map<String, String>.from(json.decode(map['overrides'] ?? '{}')),
      linkedNoteId: map['linked_note_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  // Convert CalendarEvent to SQLite row
  Map<String, dynamic> _eventToSqlite(CalendarEvent event) {
    return {
      'id': event.id,
      'user_id': event.userId,
      'title': event.title,
      'note_body': event.noteBody,
      'event_date': event.eventDate.toIso8601String().split('T')[0],
      'event_time': event.eventTime,
      'is_done': event.isDone ? 1 : 0,
      'reminder': event.reminder,
      'recurrence_type': event.recurrenceType,
      'recurrence_days': json.encode(event.recurrenceDays),
      'completed_dates': json.encode(event.completedDates),
      'overrides': json.encode(event.overrides),
      'linked_note_id': event.linkedNoteId,
      'created_at': event.createdAt.toIso8601String(),
      'updated_at': event.updatedAt?.toIso8601String() ?? event.createdAt.toIso8601String(),
      'sort_order': event.sortOrder,
    };
  }

  // Convert camelCase map to snake_case
  Map<String, dynamic> _convertToSnakeCase(Map<String, dynamic> updates) {
    final result = <String, dynamic>{};
    updates.forEach((key, value) {
      final snakeKey = key.replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)!.toLowerCase()}');
      result[snakeKey] = value;
    });
    return result;
  }

  // Check if an event occurs on a specific date
  bool _eventOccursOnDate(CalendarEvent event, DateTime date) {
    final dateStr = date.toIso8601String().split('T')[0];
    if (event.recurrenceType == null || event.recurrenceType == 'none' || event.recurrenceType!.isEmpty) {
      return event.eventDate.year == date.year && 
             event.eventDate.month == date.month && 
             event.eventDate.day == date.day;
    }

    if (event.overrides.containsValue(dateStr)) return true;

    final startDay = DateTime(event.eventDate.year, event.eventDate.month, event.eventDate.day);
    final checkDay = DateTime(date.year, date.month, date.day);
    
    if (checkDay.isBefore(startDay)) return false;
    if (event.completedDates.contains(dateStr)) return false;
    if (event.overrides.containsKey(dateStr)) return false;

    if (event.recurrenceType == 'daily') return true;
    if (event.recurrenceType == 'weekly') return event.recurrenceDays.contains(checkDay.weekday % 7);
    if (event.recurrenceType == 'monthly') return event.recurrenceDays.contains(checkDay.day);

    return false;
  }

  // Get all events for user
  Future<List<CalendarEvent>> getEvents() async {
    if (_userId.isEmpty) return [];

    if (kIsWeb) {
      final response = await _client
          .from('calendar_events')
          .select()
          .eq('user_id', _userId);
      return (response as List).map((e) => CalendarEvent.fromSupabase(e)).toList();
    } else {
      final data = await LocalDatabaseService.instance.getCalendarEvents(_userId);
      return data.map((e) => _eventFromSqlite(e)).toList();
    }
  }
  
  // Get events for specific date (including recurring events that match)
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final allEvents = await getEvents();
    return allEvents.where((e) => _eventOccursOnDate(e, date)).toList();
  }
  
  // Get events for a month (including recurring)
  Future<List<CalendarEvent>> getEventsForMonth(int year, int month) async {
    final allEvents = await getEvents();
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final result = <CalendarEvent>{};

    for (final event in allEvents) {
      for (int day = 1; day <= daysInMonth; day++) {
        if (_eventOccursOnDate(event, DateTime(year, month, day))) {
          result.add(event);
          break;
        }
      }
    }
    return result.toList();
  }
  
  // Create new event
  Future<CalendarEvent?> createEvent(CalendarEvent event) async {
    if (kIsWeb) {
      final response = await _client.from('calendar_events').insert(event.toSupabase()).select();
      if (response.isNotEmpty) {
        return CalendarEvent.fromSupabase(response.first);
      }
      return null;
    } else {
      final data = _eventToSqlite(event);
      data['sync_status'] = 1; // pendingInsert
      await LocalDatabaseService.instance.insertCalendarEvent(data);
      _triggerSync();
      return event;
    }
  }
  
  // Update event
  Future<void> updateEvent(String id, Map<String, dynamic> updates) async {
    final snakeUpdates = _convertToSnakeCase(updates);
    snakeUpdates['updated_at'] = DateTime.now().toUtc().toIso8601String();
    
    if (kIsWeb) {
      await _client.from('calendar_events').update(snakeUpdates).eq('id', id);
    } else {
      snakeUpdates['sync_status'] = 2; // pendingUpdate
      
      // JSON encode lists/maps for SQLite
      if (snakeUpdates.containsKey('recurrence_days') && snakeUpdates['recurrence_days'] is! String) {
        snakeUpdates['recurrence_days'] = json.encode(snakeUpdates['recurrence_days']);
      }
      if (snakeUpdates.containsKey('completed_dates') && snakeUpdates['completed_dates'] is! String) {
        snakeUpdates['completed_dates'] = json.encode(snakeUpdates['completed_dates']);
      }
      if (snakeUpdates.containsKey('overrides') && snakeUpdates['overrides'] is! String) {
        snakeUpdates['overrides'] = json.encode(snakeUpdates['overrides']);
      }
      if (snakeUpdates.containsKey('is_done') && snakeUpdates['is_done'] is bool) {
        snakeUpdates['is_done'] = snakeUpdates['is_done'] ? 1 : 0;
      }
      
      await LocalDatabaseService.instance.updateCalendarEvent(id, snakeUpdates);
      _triggerSync();
    }
  }
  
  // Delete event  
  Future<void> deleteEvent(String id) async {
    if (kIsWeb) {
      await _client.from('calendar_events').delete().eq('id', id);
    } else {
      await LocalDatabaseService.instance.updateCalendarEvent(id, {'sync_status': 3});
      _triggerSync();
    }
  }
  
  // Mark event done (for recurring: add to completedDates; for non-recurring: set isDone)
  Future<void> markEventDone(String id, {DateTime? occurrenceDate}) async {
    final allEvents = await getEvents();
    final event = allEvents.firstWhere((e) => e.id == id);
    
    if (event.recurrenceType == null || event.recurrenceType == 'none' || event.recurrenceType!.isEmpty) {
      await updateEvent(id, {'isDone': true});
    } else {
      if (occurrenceDate != null) {
        final dateStr = occurrenceDate.toIso8601String().split('T')[0];
        final completedDates = List<String>.from(event.completedDates);
        if (!completedDates.contains(dateStr)) {
          completedDates.add(dateStr);
          await updateEvent(id, {'completedDates': completedDates});
        }
      }
    }
  }
  
  // Move event to new date (for recurring: add override; for non-recurring: update eventDate)
  Future<void> moveEvent(String id, DateTime newDate, {DateTime? occurrenceDate}) async {
    final allEvents = await getEvents();
    final event = allEvents.firstWhere((e) => e.id == id);
    
    final newDateStr = newDate.toIso8601String().split('T')[0];
    
    if (event.recurrenceType == null || event.recurrenceType == 'none' || event.recurrenceType!.isEmpty) {
      await updateEvent(id, {'eventDate': newDateStr});
    } else {
      if (occurrenceDate != null) {
        final origDateStr = occurrenceDate.toIso8601String().split('T')[0];
        final overrides = Map<String, String>.from(event.overrides);
        overrides[origDateStr] = newDateStr;
        await updateEvent(id, {'overrides': overrides});
      }
    }
  }
  
  // Get events linked to a specific note
  Future<List<CalendarEvent>> getEventsForNote(String noteId) async {
    final allEvents = await getEvents();
    return allEvents.where((e) => e.linkedNoteId == noteId).toList();
  }

  // Bulk update the sort order for a list of events
  Future<void> updateEventOrders(List<CalendarEvent> events) async {
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      if (event.id != null) {
        await updateEvent(event.id!, {'sortOrder': i});
      }
    }
  }
}
