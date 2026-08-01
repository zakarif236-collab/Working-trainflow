# Earn Build Points by Watching Ads — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the "+2 builds per rewarded ad" save-flow reward with a "1 ad = 1 build point" model, and add a dedicated, repeatable **Earn Points** card on the Workout Builder page that grants 1 build point per rewarded ad, capped at 5 per day.

**Architecture:** Two testable building blocks, then page integration. `SettingsService` gains two SharedPreferences-backed methods (`loadAdWatchCountForToday`, `recordAdWatchForToday`) storing a `{"date", "count"}` JSON map under `builder.adWatches` with calendar-day reset. A new presentational `EarnPointsCard` widget shows balance, daily progress, a "Watch Ad (+1)" button (disabled at cap), and helper copy; it receives values + a callback so it is testable in isolation. `WorkoutBuilderPage` wires the card above the "Create Workout" card, reusing the existing `_loadRewardedAd`/`_showRewardedAd` plumbing, and the save-flow reward changes from +2 to +1.

**Tech Stack:** Flutter / Dart, `shared_preferences`, `google_mobile_ads` (existing rewarded ad plumbing only — no new ad-loading code), `firebase_auth`/`cloud_firestore` (present in the page but untouched).

## Global Constraints

- Watching one rewarded ad awards exactly **1 build point**; repeatable within the daily cap.
- Daily cap: **5 ad-watch points per day**; the "Watch Ad (+1)" button is disabled at the cap and the count resets on the next calendar day.
- Persistence key: `builder.adWatches`, stored as JSON `{"date": "yyyy-MM-dd", "count": n}`. A stale `date` means the count is 0 for today.
- The **Earn Points** card appears above the "Create Workout" card in the `ListView` only when `widget.showBuilder` is true.
- The save-flow rewarded-ad prompt now grants **+1** build (was +2). The initial free build of 1 is unchanged.
- Reuse the page's existing `_loadRewardedAd()` / `_showRewardedAd(VoidCallback onReward)`; do not add new ad-loading code.
- Helper line copy (exact): "Watch ads to earn build points, used when you save a new workout."
- No comments in code unless the existing file style requires them.

---

### Task 1: `SettingsService` — daily ad-watch persistence

**Files:**
- Modify: `lib/services/settings_service.dart` (add two methods after `addBuilderBuilds` ~line 168; add `_dateKey` helper near `_epochDay` ~line 949; add the `_kBuilderAdWatches` key constant near line 1059)
- Test: `test/builder_ad_watches_test.dart` (new)

**Interfaces:**
- Produces:
  - `Future<int> loadAdWatchCountForToday({DateTime? now})` — returns the count of rewarded ads watched today (0 when nothing stored, when the stored date is stale, or on corrupt JSON).
  - `Future<void> recordAdWatchForToday({DateTime? now})` — increments today's count in storage.
  - The optional `now` param enables deterministic tests, matching the existing `shouldSendMissedWorkoutReminder({DateTime? now})` pattern. Callers use the default (`DateTime.now()`).
  - Consumed by Task 3 (`_loadAdWatchCountForToday`, `_watchAdForPoint`).

- [ ] **Step 1: Write the failing test**

Create `test/builder_ad_watches_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadAdWatchCountForToday returns 0 when no data is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 0);
  });

  test('loadAdWatchCountForToday returns the count for the stored day',
      () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":3}',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 3);
  });

  test('loadAdWatchCountForToday resets to 0 on a new calendar day', () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":3}',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 2)), 0);
  });

  test('loadAdWatchCountForToday falls back to 0 on corrupt JSON', () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': 'not-json{',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 0);
  });

  test('recordAdWatchForToday increments across multiple calls', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 1));
    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 1));

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 2);
  });

  test('recordAdWatchForToday starts a fresh count on a new calendar day',
      () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":4}',
    });
    final settings = SettingsService();

    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 2));

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 2)), 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/builder_ad_watches_test.dart`
Expected: FAIL — compile error "The method 'loadAdWatchCountForToday' isn't defined for the type 'SettingsService'".

- [ ] **Step 3: Write minimal implementation**

In `lib/services/settings_service.dart`, insert right after the `addBuilderBuilds` method (which ends at line 168):

```dart
  Future<int> loadAdWatchCountForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_kBuilderAdWatches);
    if (encoded == null || encoded.trim().isEmpty) {
      return 0;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return 0;
      }

      if (decoded['date'] != _dateKey(now ?? DateTime.now())) {
        return 0;
      }

      return (decoded['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordAdWatchForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAdWatchCountForToday(now: now);
    await prefs.setString(
      _kBuilderAdWatches,
      jsonEncode({'date': _dateKey(now ?? DateTime.now()), 'count': current + 1}),
    );
  }
```

Near `_epochDay` (line 949), add the date-key helper:

```dart
  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
```

In the key-constant block near line 1059, add after `_kBuilderBuildsInitialized`:

```dart
const _kBuilderAdWatches = 'builder.adWatches';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/builder_ad_watches_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/settings_service.dart test/builder_ad_watches_test.dart
git commit -m "feat: track daily rewarded ad watches in settings service"
```

---

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

### Task 3: Wire `EarnPointsCard` into the page + unify save-flow reward to +1

**Files:**
- Modify: `lib/pages/workout_builder_page.dart` (import ~line 11; state fields ~line 35; `initState` ~line 46; new methods after `_loadBuilderBuildsRemaining` ~line 62; `_saveRoutine` line 285; `_promptWatchAdForBuild` line 309; mount card above the "Create Workout" card ~line 465)

**Interfaces:**
- Consumes: `EarnPointsCard` from Task 2; `loadAdWatchCountForToday` / `recordAdWatchForToday` from Task 1.
- Produces: page behavior — card above the builder card (only when `widget.showBuilder`), reward callback records the watch then adds 1 build point, button disabled at cap.

- [ ] **Step 1: Add the import**

In `lib/pages/workout_builder_page.dart`, after the existing imports (line 11):

```dart
import 'package:my_app/widgets/earn_points_card.dart';
```

- [ ] **Step 2: Add state fields**

In `_WorkoutBuilderPageState`, change the block at lines 35-37:

```dart
  int _builderBuildsRemaining = 1;
  RewardedAd? _rewardedAd;
  VoidCallback? _pendingReward;
```

to:

```dart
  static const int _kMaxDailyAdWatches = 5;

  int _builderBuildsRemaining = 1;
  int _todayAdWatches = 0;
  RewardedAd? _rewardedAd;
  VoidCallback? _pendingReward;
```

- [ ] **Step 3: Load the counter in `initState`**

In `initState` (lines 47-52), add the load call after `_loadBuilderBuildsRemaining();`:

```dart
  @override
  void initState() {
    super.initState();
    _loadSavedRoutines();
    _loadBuilderBuildsRemaining();
    _loadAdWatchCountForToday();
    _loadRewardedAd();
  }
```

- [ ] **Step 4: Add the load + reward methods**

After the `_loadBuilderBuildsRemaining` method (which ends at line 62), insert:

```dart
  Future<void> _loadAdWatchCountForToday() async {
    final count = await _settingsService.loadAdWatchCountForToday();
    if (!mounted) {
      return;
    }
    setState(() {
      _todayAdWatches = count;
    });
  }

  void _watchAdForPoint() {
    _showRewardedAd(() async {
      await _settingsService.recordAdWatchForToday();
      await _settingsService.addBuilderBuilds(1);
      if (!mounted) {
        return;
      }
      setState(() {
        _todayAdWatches += 1;
      });
      await _loadBuilderBuildsRemaining();
    });
  }
```

- [ ] **Step 5: Change the save-flow reward to +1**

In `_saveRoutine()` (line 285), change:

```dart
          await _settingsService.addBuilderBuilds(2);
```

to:

```dart
          await _settingsService.addBuilderBuilds(1);
```

- [ ] **Step 6: Update the save-flow prompt copy**

In `_promptWatchAdForBuild()` (line 300), change the dialog's `content` (currently lines 307-310) from "+2 extra builds" to "+1 extra build". The `content` becomes:

```dart
          content: const Text(
            'You have used your free workout build. '
            'Watch a rewarded ad to unlock 1 extra build?',
          ),
```

- [ ] **Step 7: Mount the card above the "Create Workout" card**

In `build`, inside the `if (widget.showBuilder) ...[` spread at line 465, insert the card before the existing `Container(` that starts the "Create Workout" card:

```dart
            if (widget.showBuilder) ...[
              EarnPointsCard(
                buildPoints: _builderBuildsRemaining,
                todayWatches: _todayAdWatches,
                maxDailyWatches: _kMaxDailyAdWatches,
                onWatchAd: _todayAdWatches >= _kMaxDailyAdWatches
                    ? null
                    : _watchAdForPoint,
              ),
              const SizedBox(height: 16),
              Container(
```

(The `Container(` is the pre-existing "Create Workout" card start at line 466; only the card, the spacing, and the `if` line are shown above — the rest of that block is unchanged.)

- [ ] **Step 8: Run the full test suite**

Run: `flutter test`
Expected: The two new test files pass, and the previously-passing tests (`builder_builds_test.dart`, `scaled_banner_ad_test.dart`, `header_banner_ad_test.dart`) still pass. The 3 pre-existing `widget_test.dart` failures (`FirebaseException: [core/no-app]` in `AuthService`) are unrelated WIP and remain. Reason this task has no new automated test: `WorkoutBuilderPage` cannot be pumped in a widget test because `_communityService = CommunityFirestoreService.instance` touches `FirebaseFirestore.instance` at field-init, which throws without a Firebase app (same root cause as the pre-existing `widget_test.dart` failures).

- [ ] **Step 9: Run static analysis**

Run: `flutter analyze`
Expected: No new issues in `workout_builder_page.dart` (pre-existing issues in WIP files like `community_page.dart`, `home_page.dart`, etc. remain).

- [ ] **Step 10: Manual verification checklist (on device/emulator)**

1. Open Workout Builder → the "Earn Points" card shows above "Create Workout", balance reflects current builds, progress shows "0/5 today".
2. Tap "Watch Ad (+1)" → rewarded ad plays; on reward the balance increases by 1 and progress shows "1/5 today".
3. After 5 watches, the button is disabled ("0/5" vs "5/5 today" state).
4. In a new session the next calendar day, the count starts at "0/5 today".
5. Save-flow prompt (after free build is consumed) says "unlock 1 extra build" and the save proceeds.

- [ ] **Step 11: Commit**

```bash
git add lib/pages/workout_builder_page.dart
git commit -m "feat: show earn points card and award one build per ad"
```
