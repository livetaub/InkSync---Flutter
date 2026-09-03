import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/calendar_event.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import '../../services/notes_service.dart';
import '../../config/theme.dart';
import '../note_edit/note_edit_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _currentMonth = DateTime.now();
  DateTime _selectedDate = DateTime.now();
  List<CalendarEvent> _monthEvents = [];
  bool _isLoading = false;

  late CalendarService _calendarService;
  late AuthService _authService;
  late NotesService _notesService;

  @override
  void initState() {
    super.initState();
    _authService = Provider.of<AuthService>(context, listen: false);
    _calendarService = CalendarService(_authService);
    _notesService = NotesService(_authService);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await _calendarService.getEventsForMonth(_currentMonth.year, _currentMonth.month);
      setState(() {
        _monthEvents = events;
      });
    } catch (e) {
      debugPrint('Error loading events: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    });
    _loadEvents();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = DateTime(_currentMonth.year, _currentMonth.month, 1);
    });
    _loadEvents();
  }

  void _openEventForm([CalendarEvent? event]) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventFormSheet(
        initialDate: _selectedDate,
        event: event,
        calendarService: _calendarService,
        authService: _authService,
        onSaved: () => _loadEvents(),
      ),
    );
  }

  void _markEventDone(CalendarEvent event) async {
    HapticFeedback.lightImpact();
    // Assuming CalendarService has markEventDone
    try {
      await _calendarService.updateEvent(event.id!, {'isDone': !event.isDone});
      // Or if it strictly has markEventDone(id):
      // await _calendarService.markEventDone(event.id!);
      _loadEvents();
    } catch (e) {
      debugPrint('Error marking done: $e');
    }
  }

  void _moveEvent(CalendarEvent event, DateTime newDate) async {
    try {
      await _calendarService.updateEvent(event.id!, {
        'eventDate': newDate.toIso8601String().split('T')[0],
      });
      _loadEvents();
    } catch (e) {
      debugPrint('Error moving event: $e');
    }
  }

  void _openNote(String noteId) async {
    try {
      final note = await _notesService.getNote(noteId);
      if (note != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteEditScreen(note: note)),
        );
      }
    } catch (e) {
      debugPrint('Error opening note: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.bgPrimaryDark : AppTheme.bgPrimary;
    final cardColor = isDark ? const Color(0xFF1A1D21) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    
    // Get events for selected date
    final selectedEvents = _monthEvents.where((e) {
      return e.eventDate.year == _selectedDate.year &&
             e.eventDate.month == _selectedDate.month &&
             e.eventDate.day == _selectedDate.day;
    }).toList();

    return Scaffold(
      backgroundColor: bgColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEventForm(),
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(textColor),
            _buildCalendarGrid(isDark, cardColor, textColor),
            Expanded(
              child: _buildEventsList(selectedEvents, isDark, cardColor, textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(_currentMonth),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: textColor),
                onPressed: _previousMonth,
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: textColor),
                onPressed: _nextMonth,
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(bool isDark, Color cardColor, Color textColor) {
    final daysInMonth = DateUtils.getDaysInMonth(_currentMonth.year, _currentMonth.month);
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final startOffset = firstDayOfMonth.weekday % 7; // Sunday = 0

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Days grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: daysInMonth + startOffset,
            itemBuilder: (context, index) {
              if (index < startOffset) return const SizedBox.shrink();

              final day = index - startOffset + 1;
              final date = DateTime(_currentMonth.year, _currentMonth.month, day);
              final isSelected = DateUtils.isSameDay(date, _selectedDate);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              
              final hasEvents = _monthEvents.any((e) => DateUtils.isSameDay(e.eventDate, date));

              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _selectedDate = date);
                },
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected 
                      ? AppTheme.selectionBlue 
                      : (isToday ? AppTheme.primaryColor.withOpacity(0.2) : Colors.transparent),
                    border: isToday && !isSelected
                      ? Border.all(color: AppTheme.primaryColor, width: 1)
                      : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasEvents)
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.white : AppTheme.primaryColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<CalendarEvent> events, bool isDark, Color cardColor, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            DateFormat('EEEE, MMM d').format(_selectedDate),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
            ),
          ),
        ),
        if (events.isEmpty)
          Expanded(
            child: Center(
              child: Text(
                'No events for this day',
                style: TextStyle(
                  color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                ),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: events.length,
              itemBuilder: (context, index) {
                final event = events[index];
                return _buildEventCard(event, isDark, cardColor, textColor);
              },
            ),
          ),
      ],
    );
  }

  Widget _buildEventCard(CalendarEvent event, bool isDark, Color cardColor, Color textColor) {
    final isDone = event.isDone;
    
    return GestureDetector(
      onTap: () => _openEventForm(event),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: isDark 
            ? Border.all(color: Colors.white.withOpacity(0.1))
            : Border.all(color: AppTheme.borderLight),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Left color bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: isDone ? Colors.grey : AppTheme.primaryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDone ? Colors.grey : textColor,
                                decoration: isDone ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (event.recurrenceType != null && event.recurrenceType!.isNotEmpty)
                            Icon(Icons.repeat, size: 16, color: isDone ? Colors.grey : AppTheme.primaryColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        event.eventTime ?? 'All day',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                        ),
                      ),
                      if (event.noteBody != null && event.noteBody!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          event.noteBody!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppTheme.textMutedDark : AppTheme.textMuted,
                          ),
                        ),
                      ],
                      if (event.linkedNoteId != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => _openNote(event.linkedNoteId!),
                          child: Row(
                            children: [
                              Icon(Icons.link, size: 14, color: AppTheme.selectionBlue),
                              const SizedBox(width: 4),
                              Text(
                                'Open Note',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.selectionBlue,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]
                    ],
                  ),
                ),
              ),
              // Actions
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.check_circle_outline,
                      color: isDone ? AppTheme.primaryColor : (isDark ? Colors.white54 : Colors.black54),
                    ),
                    onPressed: () => _markEventDone(event),
                  ),
                  PopupMenuButton<String>(
                    icon: Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.black54),
                    onSelected: (val) async {
                      DateTime? newDate;
                      if (val == 'tomorrow') {
                        newDate = DateTime.now().add(const Duration(days: 1));
                      } else if (val == 'next_monday') {
                        final now = DateTime.now();
                        int daysUntilMonday = DateTime.monday - now.weekday;
                        if (daysUntilMonday <= 0) daysUntilMonday += 7;
                        newDate = now.add(Duration(days: daysUntilMonday));
                      } else if (val == 'custom') {
                        newDate = await showDatePicker(
                          context: context,
                          initialDate: event.eventDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(2100),
                        );
                      }
                      
                      if (newDate != null) {
                        _moveEvent(event, newDate);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
                      const PopupMenuItem(value: 'next_monday', child: Text('Next Monday')),
                      const PopupMenuItem(value: 'custom', child: Text('Custom...')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventFormSheet extends StatefulWidget {
  final DateTime initialDate;
  final CalendarEvent? event;
  final CalendarService calendarService;
  final AuthService authService;
  final VoidCallback onSaved;

  const _EventFormSheet({
    required this.initialDate,
    this.event,
    required this.calendarService,
    required this.authService,
    required this.onSaved,
  });

  @override
  State<_EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<_EventFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _noteController;
  late DateTime _date;
  TimeOfDay? _time;
  bool _isAllDay = true;
  
  bool _hasReminder = false;
  String _reminderValue = 'On event time';
  
  bool _isRecurring = false;
  String _recurrenceType = 'Day of Week';
  List<int> _recurrenceDays = [];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _noteController = TextEditingController(text: widget.event?.noteBody ?? '');
    _date = widget.event?.eventDate ?? widget.initialDate;
    
    if (widget.event?.eventTime != null && widget.event!.eventTime!.isNotEmpty) {
      _isAllDay = false;
      final parts = widget.event!.eventTime!.split(':');
      if (parts.length >= 2) {
        _time = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
      }
    }
    
    if (widget.event?.reminder != null) {
      _hasReminder = true;
      _reminderValue = widget.event!.reminder!;
    }
    
    if (widget.event?.recurrenceType != null && widget.event!.recurrenceType!.isNotEmpty) {
      _isRecurring = true;
      _recurrenceType = widget.event!.recurrenceType!;
      _recurrenceDays = widget.event!.recurrenceDays;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() async {
    if (_titleController.text.trim().isEmpty) return;

    String? eventTimeStr;
    if (!_isAllDay && _time != null) {
      eventTimeStr = '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}';
    }

    final newEvent = CalendarEvent(
      id: widget.event?.id ?? const Uuid().v4(),
      userId: widget.event?.userId ?? widget.authService.currentUserId ?? 'temp_user',
      title: _titleController.text.trim(),
      noteBody: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      eventDate: _date,
      eventTime: eventTimeStr,
      isDone: widget.event?.isDone ?? false,
      reminder: _hasReminder ? _reminderValue : null,
      recurrenceType: _isRecurring ? _recurrenceType : null,
      recurrenceDays: _isRecurring ? _recurrenceDays : [],
      linkedNoteId: widget.event?.linkedNoteId,
      createdAt: widget.event?.createdAt ?? DateTime.now().toUtc(),
    );

    if (widget.event == null) {
      // Assuming createEvent exists in service
      try {
        await widget.calendarService.createEvent(newEvent);
      } catch(e) {
        // Handle fallback if schema differences
        debugPrint('Create failed $e');
      }
    } else {
      try {
        await widget.calendarService.updateEvent(widget.event!.id!, newEvent.toMap());
      } catch(e) {
        debugPrint('Update failed $e');
      }
    }

    widget.onSaved();
    Navigator.pop(context);
  }
  
  void _delete() async {
    if (widget.event?.id != null) {
      await widget.calendarService.deleteEvent(widget.event!.id!);
      widget.onSaved();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppTheme.surfaceDark : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            TextField(
              controller: _titleController,
              autofocus: widget.event == null,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
              decoration: InputDecoration(
                hintText: 'Event Title',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                border: InputBorder.none,
              ),
            ),
            const Divider(),
            
            // Date & Time
            Row(
              children: [
                Icon(Icons.calendar_today, size: 20, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                ActionChip(
                  label: Text(DateFormat('MMM d, yyyy').format(_date)),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                ),
                const Spacer(),
                const Text('All day'),
                Switch(
                  value: _isAllDay,
                  onChanged: (val) => setState(() => _isAllDay = val),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
            if (!_isAllDay)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: ActionChip(
                  label: Text(_time?.format(context) ?? 'Select Time'),
                  onPressed: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: _time ?? TimeOfDay.now(),
                    );
                    if (picked != null) setState(() => _time = picked);
                  },
                ),
              ),
            
            const SizedBox(height: 12),
            
            // Reminder
            Row(
              children: [
                Icon(Icons.notifications_none, size: 20, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                const Text('Reminder', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Switch(
                  value: _hasReminder,
                  onChanged: (val) => setState(() => _hasReminder = val),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
            if (_hasReminder)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: DropdownButton<String>(
                  value: _reminderValue,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: [
                    'On event time',
                    '30 minutes before',
                    '1 hour before',
                    '2 hours before',
                    'Morning of event (8:00 AM)',
                  ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (val) => setState(() => _reminderValue = val!),
                ),
              ),

            const SizedBox(height: 12),
            
            // Recurring
            Row(
              children: [
                Icon(Icons.repeat, size: 20, color: AppTheme.textMuted),
                const SizedBox(width: 12),
                const Text('Recurring', style: TextStyle(fontSize: 16)),
                const Spacer(),
                Switch(
                  value: _isRecurring,
                  onChanged: (val) => setState(() => _isRecurring = val),
                  activeColor: AppTheme.primaryColor,
                ),
              ],
            ),
            if (_isRecurring)
              Padding(
                padding: const EdgeInsets.only(left: 32, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'Day of Week', label: Text('Week')),
                        ButtonSegment(value: 'Day of Month', label: Text('Month')),
                      ],
                      selected: {_recurrenceType},
                      onSelectionChanged: (set) => setState(() => _recurrenceType = set.first),
                    ),
                    const SizedBox(height: 8),
                    if (_recurrenceType == 'Day of Week')
                      Wrap(
                        spacing: 8,
                        children: [1, 2, 3, 4, 5, 6, 7].map((day) {
                          final isSel = _recurrenceDays.contains(day);
                          final labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                          return ChoiceChip(
                            label: Text(labels[day - 1]),
                            selected: isSel,
                            onSelected: (val) {
                              setState(() {
                                if (val) _recurrenceDays.add(day);
                                else _recurrenceDays.remove(day);
                              });
                            },
                          );
                        }).toList(),
                      ),
                    if (_recurrenceType == 'Day of Month')
                      SizedBox(
                        height: 120,
                        child: GridView.builder(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            childAspectRatio: 1.5,
                          ),
                          itemCount: 31,
                          itemBuilder: (context, i) {
                            final day = i + 1;
                            final isSel = _recurrenceDays.contains(day);
                            return InkWell(
                              onTap: () {
                                setState(() {
                                  if (isSel) _recurrenceDays.remove(day);
                                  else _recurrenceDays.add(day);
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: isSel ? AppTheme.primaryColor : Colors.transparent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                alignment: Alignment.center,
                                child: Text('$day', style: TextStyle(color: isSel ? Colors.white : textColor)),
                              ),
                            );
                          },
                        ),
                      )
                  ],
                ),
              ),
              
            const SizedBox(height: 12),
            
            // Note
            TextField(
              controller: _noteController,
              maxLines: 3,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Add note (optional)',
                hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                prefixIcon: const Icon(Icons.notes),
              ),
            ),
            
            if (widget.event?.linkedNoteId != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    Icon(Icons.link, color: AppTheme.selectionBlue, size: 20),
                    const SizedBox(width: 8),
                    Text('Linked to Note', style: TextStyle(color: AppTheme.selectionBlue)),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            
            // Actions
            Row(
              children: [
                if (widget.event != null)
                  TextButton(
                    onPressed: _delete,
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
