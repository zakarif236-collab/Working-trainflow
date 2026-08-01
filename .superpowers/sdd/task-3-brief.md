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

