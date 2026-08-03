import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/workout_schedule_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the reminders toggle and expands when enabled',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WorkoutScheduleSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout Reminders'), findsOneWidget);
    expect(find.text('DAYS OF THE WEEK'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('DAYS OF THE WEEK'), findsOneWidget);
    expect(find.text('TIME OF DAY'), findsOneWidget);
    expect(find.text('FREQUENCY'), findsOneWidget);
    expect(find.text('Schedule Summary'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
