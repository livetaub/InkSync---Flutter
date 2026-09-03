import 'dart:convert';

class CalendarEvent {
  final String? id;
  final String userId;
  final String title;
  final String? noteBody;
  final DateTime eventDate;
  final String? eventTime;
  final bool isDone;
  final String? reminder;
  final String? recurrenceType;
  final List<int> recurrenceDays;
  final List<String> completedDates;
  final Map<String, String> overrides;
  final String? linkedNoteId;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final int sortOrder;

  CalendarEvent({
    this.id,
    required this.userId,
    required this.title,
    this.noteBody,
    required this.eventDate,
    this.eventTime,
    this.isDone = false,
    this.reminder,
    this.recurrenceType,
    this.recurrenceDays = const [],
    this.completedDates = const [],
    this.overrides = const {},
    this.linkedNoteId,
    required this.createdAt,
    this.updatedAt,
    this.sortOrder = 0,
  });

  factory CalendarEvent.fromMap(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      userId: map['userId'] ?? '',
      title: map['title'] ?? '',
      noteBody: map['noteBody'],
      eventDate: DateTime.parse(map['eventDate']),
      eventTime: map['eventTime'],
      isDone: map['isDone'] == 1,
      reminder: map['reminder'],
      recurrenceType: map['recurrenceType'],
      recurrenceDays: List<int>.from(json.decode(map['recurrenceDays'] ?? '[]')),
      completedDates: List<String>.from(json.decode(map['completedDates'] ?? '[]')),
      overrides: Map<String, String>.from(json.decode(map['overrides'] ?? '{}')),
      linkedNoteId: map['linkedNoteId'],
      createdAt: DateTime.parse(map['createdAt']),
      updatedAt: map['updatedAt'] != null ? DateTime.parse(map['updatedAt']) : null,
      sortOrder: map['sortOrder'] ?? 0,
    );
  }

  factory CalendarEvent.fromSupabase(Map<String, dynamic> map) {
    return CalendarEvent(
      id: map['id'],
      userId: map['user_id'] ?? '',
      title: map['title'] ?? '',
      noteBody: map['note_body'],
      eventDate: DateTime.parse(map['event_date']),
      eventTime: map['event_time'],
      isDone: map['is_done'] == true,
      reminder: map['reminder'],
      recurrenceType: map['recurrence_type'],
      recurrenceDays: List<int>.from(map['recurrence_days'] ?? []),
      completedDates: List<String>.from(map['completed_dates'] ?? []),
      overrides: Map<String, String>.from(map['overrides'] ?? {}),
      linkedNoteId: map['linked_note_id'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: map['updated_at'] != null ? DateTime.parse(map['updated_at']) : null,
      sortOrder: map['sort_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'noteBody': noteBody,
      'eventDate': eventDate.toIso8601String(),
      'eventTime': eventTime,
      'isDone': isDone ? 1 : 0,
      'reminder': reminder,
      'recurrenceType': recurrenceType,
      'recurrenceDays': json.encode(recurrenceDays),
      'completedDates': json.encode(completedDates),
      'overrides': json.encode(overrides),
      'linkedNoteId': linkedNoteId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'sortOrder': sortOrder,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'title': title,
      if (noteBody != null) 'note_body': noteBody,
      'event_date': eventDate.toIso8601String().split('T')[0],
      if (eventTime != null) 'event_time': eventTime,
      'is_done': isDone,
      if (reminder != null) 'reminder': reminder,
      if (recurrenceType != null) 'recurrence_type': recurrenceType,
      'recurrence_days': recurrenceDays,
      'completed_dates': completedDates,
      'overrides': overrides,
      if (linkedNoteId != null) 'linked_note_id': linkedNoteId,
      'created_at': createdAt.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      'sort_order': sortOrder,
    };
  }

  CalendarEvent copyWith({
    String? id,
    String? userId,
    String? title,
    String? noteBody,
    DateTime? eventDate,
    String? eventTime,
    bool? isDone,
    String? reminder,
    String? recurrenceType,
    List<int>? recurrenceDays,
    List<String>? completedDates,
    Map<String, String>? overrides,
    String? linkedNoteId,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? sortOrder,
  }) {
    return CalendarEvent(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      noteBody: noteBody ?? this.noteBody,
      eventDate: eventDate ?? this.eventDate,
      eventTime: eventTime ?? this.eventTime,
      isDone: isDone ?? this.isDone,
      reminder: reminder ?? this.reminder,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDays: recurrenceDays ?? this.recurrenceDays,
      completedDates: completedDates ?? this.completedDates,
      overrides: overrides ?? this.overrides,
      linkedNoteId: linkedNoteId ?? this.linkedNoteId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
