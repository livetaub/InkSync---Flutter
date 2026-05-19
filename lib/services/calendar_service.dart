import 'package:flutter/foundation.dart';
import 'auth_service.dart';
import 'notes_service.dart';

/// CalendarEvent Model
/// Note: Calendar events are derived from notes with reminders
/// since we don't have a separate calendar_events table in the schema
class CalendarEvent {
  final String? id;
  final String title;
  final String description;
  final DateTime date;
  final bool isAllDay;
  final String? startTime;
  final String? endTime;
  final bool isReminder;
  final String color;
  final String? noteId;
  final String? createdBy;
  final DateTime? createdDate;
  final DateTime? updatedDate;

  CalendarEvent({
    this.id,
    this.title = '',
    this.description = '',
    required this.date,
    this.isAllDay = true,
    this.startTime,
    this.endTime,
    this.isReminder = false,
    this.color = 'teal',
    this.noteId,
    this.createdBy,
    this.createdDate,
    this.updatedDate,
  });

  factory CalendarEvent.fromNote(Note note) {
    return CalendarEvent(
      id: note.id,
      title: note.title,
      description: note.content,
      date: note.reminderAt ?? DateTime.now(),
      isAllDay: true,
      isReminder: true,
      color: note.color,
      noteId: note.id,
      createdBy: note.createdBy,
      createdDate: note.createdDate,
      updatedDate: note.updatedDate,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'date': date.toIso8601String(),
      'isAllDay': isAllDay,
      'startTime': startTime,
      'endTime': endTime,
      'isReminder': isReminder,
      'color': color,
      'noteId': noteId,
      'created_by': createdBy,
      'created_date': createdDate?.toIso8601String(),
      'updated_date': updatedDate?.toIso8601String(),
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? date,
    bool? isAllDay,
    String? startTime,
    String? endTime,
    bool? isReminder,
    String? color,
    String? noteId,
    String? createdBy,
    DateTime? createdDate,
    DateTime? updatedDate,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      date: date ?? this.date,
      isAllDay: isAllDay ?? this.isAllDay,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      isReminder: isReminder ?? this.isReminder,
      color: color ?? this.color,
      noteId: noteId ?? this.noteId,
      createdBy: createdBy ?? this.createdBy,
      createdDate: createdDate ?? this.createdDate,
      updatedDate: updatedDate ?? this.updatedDate,
    );
  }
}

/// Calendar Events Service
/// Uses notes with reminders as calendar events
class CalendarService {
  final AuthService _auth;
  late final NotesService _notesService;

  CalendarService(this._auth) {
    _notesService = NotesService(_auth);
  }

  /// Get all events (notes with reminders)
  Future<List<CalendarEvent>> getEvents() async {
    try {
      final notes = await _notesService.getActiveNotes();
      return notes
          .where((note) => note.reminderAt != null)
          .map((note) => CalendarEvent.fromNote(note))
          .toList()
        ..sort((a, b) => a.date.compareTo(b.date));
    } catch (e) {
      debugPrint('Error getting calendar events: $e');
      return [];
    }
  }

  /// Get events for a specific date
  Future<List<CalendarEvent>> getEventsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final events = await getEvents();
    return events
        .where((e) => e.date.isAfter(startOfDay) && e.date.isBefore(endOfDay))
        .toList();
  }

  /// Get events for a month
  Future<List<CalendarEvent>> getEventsForMonth(int year, int month) async {
    final startOfMonth = DateTime(year, month, 1);
    final endOfMonth = DateTime(year, month + 1, 1);

    final events = await getEvents();
    return events
        .where(
          (e) =>
              e.date.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
              e.date.isBefore(endOfMonth),
        )
        .toList();
  }

  /// Create event by setting reminder on a note
  Future<CalendarEvent?> createEvent(CalendarEvent event) async {
    if (event.noteId != null) {
      // Update existing note with reminder
      await _notesService.updateNote(event.noteId!, {
        'reminderAt': event.date.toIso8601String(),
      });
      return event;
    }

    // Create a new note with reminder
    final note = await _notesService.createNote(
      Note(
        title: event.title,
        content: event.description,
        color: event.color,
        reminderAt: event.date,
      ),
    );

    if (note != null) {
      return CalendarEvent.fromNote(note);
    }
    return null;
  }

  /// Update event (update the note's reminder)
  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    if (updates.containsKey('date')) {
      await _notesService.updateNote(eventId, {'reminderAt': updates['date']});
    }
  }

  /// Delete event (remove reminder from note)
  Future<void> deleteEvent(String eventId) async {
    await _notesService.updateNote(eventId, {'reminderAt': null});
  }
}
