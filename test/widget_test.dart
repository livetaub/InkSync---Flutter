// Basic Flutter widget test for InkSync
import 'package:flutter_test/flutter_test.dart';
import 'package:inksync/main.dart';

void main() {
  testWidgets('InkSync app loads', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const InkSyncApp());

    // Verify the app loads (this is a basic smoke test)
    expect(find.byType(InkSyncApp), findsOneWidget);
  });
}
