import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/earn_points_card.dart';

void main() {
  testWidgets('shows balance, daily progress, and helper copy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EarnPointsCard(
            buildPoints: 3,
            todayWatches: 2,
            maxDailyWatches: 5,
            onWatchAd: null,
          ),
        ),
      ),
    );

    expect(find.text('Earn Points'), findsOneWidget);
    expect(find.text('3 build points'), findsOneWidget);
    expect(find.text('2/5 today'), findsOneWidget);
    expect(find.text('Watch Ad (+1)'), findsOneWidget);
    expect(
      find.text('Watch ads to earn build points, used when you save a new workout.'),
      findsOneWidget,
    );
  });

  testWidgets('watch button is disabled when the daily cap is reached',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EarnPointsCard(
            buildPoints: 5,
            todayWatches: 5,
            maxDailyWatches: 5,
            onWatchAd: null,
          ),
        ),
      ),
    );

    final button = tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Watch Ad (+1)'),
        matching: find.byType(FilledButton),
      ),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets('tapping Watch Ad invokes the callback', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EarnPointsCard(
            buildPoints: 1,
            todayWatches: 0,
            maxDailyWatches: 5,
            onWatchAd: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Watch Ad (+1)'));
    expect(tapped, isTrue);
  });
}
