import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/calendar_service.dart';
import '../../services/auth_service.dart';
import '../../config/theme.dart';
import '../../utils/ui_helper.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late CalendarService _calendarService;
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime.now();
  List<CalendarEvent> _events = [];
  List<CalendarEvent> _selectedDateEvents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  void _initService() {
    final authService = Provider.of<AuthService>(context, listen: false);
    _calendarService = CalendarService(authService);
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final events = await _calendarService.getEventsForMonth(
        _focusedMonth.year,
        _focusedMonth.month,
      );
      setState(() {
        _events = events;
        _updateSelectedDateEvents();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading events: $e')));
      }
    }
  }

  void _updateSelectedDateEvents() {
    _selectedDateEvents = _events.where((event) {
      return event.date.year == _selectedDate.year &&
          event.date.month == _selectedDate.month &&
          event.date.day == _selectedDate.day;
    }).toList();
  }

  void _onDaySelected(DateTime day) {
    setState(() {
      _selectedDate = day;
      _updateSelectedDateEvents();
    });
  }

  void _onMonthChanged(int delta) {
    setState(() {
      _focusedMonth = DateTime(
        _focusedMonth.year,
        _focusedMonth.month + delta,
        1,
      );
    });
    _loadEvents();
  }

  bool _hasEventsOnDay(DateTime day) {
    return _events.any(
      (event) =>
          event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day,
    );
  }

  void _showAddEventDialog() {
    showAdaptiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: EventFormSheet(
        initialDate: _selectedDate,
        onSave: (event) async {
          await _calendarService.createEvent(event);
          _loadEvents();
        },
      ),
    );
  }

  void _showEditEventDialog(CalendarEvent event) {
    showAdaptiveModal(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: EventFormSheet(
        event: event,
        initialDate: event.date,
        onSave: (updatedEvent) async {
          await _calendarService.updateEvent(event.id!, updatedEvent.toMap());
          _loadEvents();
        },
        onDelete: () async {
          await _calendarService.deleteEvent(event.id!);
          _loadEvents();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        title: const Text('Calendar'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Calendar header
          _buildCalendarHeader(),

          // Weekday labels
          _buildWeekdayLabels(),

          // Calendar grid
          Expanded(
            flex: 2,
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildCalendarGrid(),
          ),

          // Selected date events
          Expanded(flex: 3, child: _buildEventsList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'calendar_fab',
        onPressed: _showAddEventDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildCalendarHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _onMonthChanged(-1),
          ),
          Text(
            DateFormat.yMMMM().format(_focusedMonth),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _onMonthChanged(1),
          ),
        ],
      ),
    );
  }

  Widget _buildWeekdayLabels() {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: weekdays
            .map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month,
      1,
    );
    final lastDayOfMonth = DateTime(
      _focusedMonth.year,
      _focusedMonth.month + 1,
      0,
    );
    final startingWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final days = <Widget>[];

    // Empty cells before first day
    for (int i = 0; i < startingWeekday; i++) {
      days.add(const SizedBox());
    }

    // Days of month
    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_focusedMonth.year, _focusedMonth.month, day);
      final isSelected =
          date.year == _selectedDate.year &&
          date.month == _selectedDate.month &&
          date.day == _selectedDate.day;
      final isToday =
          date.year == DateTime.now().year &&
          date.month == DateTime.now().month &&
          date.day == DateTime.now().day;
      final hasEvents = _hasEventsOnDay(date);

      days.add(
        GestureDetector(
          onTap: () => _onDaySelected(date),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryColor
                  : isToday
                  ? AppTheme.primaryColor.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: isToday && !isSelected
                  ? Border.all(color: AppTheme.primaryColor, width: 1)
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  day.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isSelected
                        ? Colors.white
                        : isToday
                        ? AppTheme.primaryColor
                        : AppTheme.textPrimary,
                  ),
                ),
                if (hasEvents)
                  Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      children: days,
    );
  }

  Widget _buildEventsList() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  DateFormat.MMMEd().format(_selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${_selectedDateEvents.length} event${_selectedDateEvents.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _selectedDateEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.event_available,
                          size: 48,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'No events',
                          style: TextStyle(color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _selectedDateEvents.length,
                    itemBuilder: (context, index) {
                      final event = _selectedDateEvents[index];
                      return _buildEventCard(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(CalendarEvent event) {
    final eventColor =
        AppTheme.noteColors[event.color] ?? AppTheme.primaryColor;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showEditEventDialog(event),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: eventColor, width: 4)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (event.isReminder)
                          const Padding(
                            padding: EdgeInsets.only(right: 4),
                            child: Icon(
                              Icons.notifications,
                              size: 14,
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            event.title.isEmpty ? 'Untitled' : event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.description.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          event.description,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                event.isAllDay
                    ? 'All day'
                    : '${event.startTime ?? ''} - ${event.endTime ?? ''}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Event Form Bottom Sheet
class EventFormSheet extends StatefulWidget {
  final CalendarEvent? event;
  final DateTime initialDate;
  final Function(CalendarEvent) onSave;
  final VoidCallback? onDelete;

  const EventFormSheet({
    super.key,
    this.event,
    required this.initialDate,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<EventFormSheet> createState() => _EventFormSheetState();
}

class _EventFormSheetState extends State<EventFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late bool _isAllDay;
  late String _startTime;
  late String _endTime;
  late bool _isReminder;
  late String _selectedColor;

  final List<String> _timeOptions = List.generate(48, (index) {
    final hour = index ~/ 2;
    final minute = (index % 2) * 30;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  });

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.event?.title ?? '');
    _descriptionController = TextEditingController(
      text: widget.event?.description ?? '',
    );
    _selectedDate = widget.event?.date ?? widget.initialDate;
    _isAllDay = widget.event?.isAllDay ?? true;
    _startTime = widget.event?.startTime ?? '09:00';
    _endTime = widget.event?.endTime ?? '10:00';
    _isReminder = widget.event?.isReminder ?? false;
    _selectedColor = widget.event?.color ?? 'teal';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final event = CalendarEvent(
      id: widget.event?.id,
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      date: _selectedDate,
      isAllDay: _isAllDay,
      startTime: _isAllDay ? null : _startTime,
      endTime: _isAllDay ? null : _endTime,
      isReminder: _isReminder,
      color: _selectedColor,
    );
    widget.onSave(event);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    widget.event == null ? 'Add Event' : 'Edit Event',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.pop(context);
                      },
                    ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Title
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  hintText: 'Event title',
                  prefixIcon: Icon(Icons.title),
                ),
              ),
              const SizedBox(height: 12),

              // Description
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  hintText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today),
                title: Text(DateFormat.yMMMd().format(_selectedDate)),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) {
                    setState(() => _selectedDate = picked);
                  }
                },
              ),

              // All day switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('All day'),
                secondary: const Icon(Icons.access_time),
                value: _isAllDay,
                onChanged: (value) => setState(() => _isAllDay = value),
              ),

              // Time pickers
              if (!_isAllDay)
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _startTime,
                        decoration: const InputDecoration(labelText: 'Start'),
                        items: _timeOptions
                            .map(
                              (time) => DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _startTime = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _endTime,
                        decoration: const InputDecoration(labelText: 'End'),
                        items: _timeOptions
                            .map(
                              (time) => DropdownMenuItem(
                                value: time,
                                child: Text(time),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _endTime = value!),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 12),

              // Reminder switch
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Reminder'),
                secondary: const Icon(Icons.notifications_outlined),
                value: _isReminder,
                onChanged: (value) => setState(() => _isReminder = value),
              ),

              // Color picker
              const SizedBox(height: 8),
              const Text(
                'Color',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: AppTheme.noteColors.entries.map((entry) {
                  final isSelected = _selectedColor == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = entry.key),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: AppTheme.primaryColor,
                            )
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _save,
                  child: Text(
                    widget.event == null ? 'Add Event' : 'Save Changes',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
