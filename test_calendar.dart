import 'package:flutter/material.dart';
import 'package:ink_sync/models/calendar_event.dart';
import 'package:ink_sync/services/calendar_service.dart';
import 'package:ink_sync/services/auth_service.dart';
import 'package:ink_sync/services/local_database_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final event = CalendarEvent(
      id: 'test_id',
      userId: 'test_user',
      title: 'Test',
      eventDate: DateTime.now(),
      createdAt: DateTime.now(),
    );
    final auth = AuthService();
    final service = CalendarService(auth);
    final map = service.eventToSqlitePublic(event);
    print(map);
  } catch(e) {
    print('Error: $e');
  }
}
