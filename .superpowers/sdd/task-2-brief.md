### Task 2: `EarnPointsCard` widget

**Files:**
- Create: `lib/widgets/earn_points_card.dart`
- Test: `test/earn_points_card_test.dart`

**Interfaces:**
- Consumes: nothing from Task 1 (pure presentational widget).
- Produces: `EarnPointsCard` — `const EarnPointsCard({super.key, required int buildPoints, required int todayWatches, required int maxDailyWatches, required VoidCallback? onWatchAd})`. Renders the card styling used across the builder page (white 0.06 alpha fill, radius 16, white24 border): an "Earn Points" title, the balance line ("3 build points"), the daily progress ("2/5 today"), a full-width "Watch Ad (+1)" `FilledButton.icon` that is disabled when `onWatchAd` is null, and the helper copy. Consumed by Task 3.
  - Note: this deviates from the spec's `_EarnPointsCard` (private-in-page) naming by making it a public widget in its own file, so it is testable in isolation. The page wires it with the same content the spec describes.
- No comments in code.

- [ ] **Step 1: Write the failing test**

Create `test/earn_points_card_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/earn_points_card_test.dart`
Expected: FAIL — "Target of URI doesn't exist: 'package:my_app/widgets/earn_points_card.dart'".

- [ ] **Step 3: Write minimal implementation**

Create `lib/widgets/earn_points_card.dart`:

```dart
import 'package:flutter/material.dart';

class EarnPointsCard extends StatelessWidget {
  const EarnPointsCard({
    super.key,
    required this.buildPoints,
    required this.todayWatches,
    required this.maxDailyWatches,
    required this.onWatchAd,
  });

  final int buildPoints;
  final int todayWatches;
  final int maxDailyWatches;
  final VoidCallback? onWatchAd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earn Points',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            buildPoints == 1 ? '1 build point' : '$buildPoints build points',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$todayWatches/$maxDailyWatches today',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWatchAd,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch Ad (+1)'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Watch ads to earn build points, used when you save a new workout.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/earn_points_card_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/earn_points_card.dart test/earn_points_card_test.dart
git commit -m "feat: add earn points card widget"
```

---

