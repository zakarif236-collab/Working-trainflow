import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_app/main.dart';
import 'package:my_app/services/auth_service.dart';

import 'firebase_test_helper.dart';

void main() {
  setUpAll(() async {
    await setupFirebaseForTesting();
  });
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(MyApp(authService: AuthService()));
    await tester.pumpAndSettle();
  }

  Future<void> openQuickStartMode(
    WidgetTester tester,
    String title,
  ) async {
    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Mods'),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Quick Start'));
    await tester.pumpAndSettle();

    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  Future<void> expectConfigLabelVisible(
    WidgetTester tester,
    String label,
  ) async {
    final finder = find.text(label);
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(finder, findsOneWidget);
  }

  testWidgets('Workout timer is shown by default on home tab', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Session Builder'), findsOneWidget);
    expect(find.text('Play Music'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VO2max quick start opens workout page', (WidgetTester tester) async {
    await pumpApp(tester);

    await openQuickStartMode(tester, 'VO2max 4x4 (Quick Start)');

    expect(find.text('Session Builder'), findsOneWidget);
    await expectConfigLabelVisible(tester, 'Work: 240s');
    await expectConfigLabelVisible(tester, 'Warmup: 600s');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calisthenics quick start opens workout page', (WidgetTester tester) async {
    await pumpApp(tester);

    await openQuickStartMode(tester, 'HIIT Cardio');

    expect(find.text('Session Builder'), findsOneWidget);
    await expectConfigLabelVisible(tester, 'Work: 40s');
    await expectConfigLabelVisible(tester, 'Warmup: 180s');
    expect(tester.takeException(), isNull);
  });
}
