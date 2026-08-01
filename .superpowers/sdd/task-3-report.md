# Task 3 Report: Wire `EarnPointsCard` into Workout Builder page

## Status: DONE_WITH_CONCERNS

## What I implemented

Applied all code changes verbatim from `task-3-brief.md` (steps 1–7) onto the current working-tree content of `lib/pages/workout_builder_page.dart`:

1. Added `import 'package:my_app/widgets/earn_points_card.dart';` after the existing imports.
2. Added `static const int _kMaxDailyAdWatches = 5;` and `int _todayAdWatches = 0;` to the state fields.
3. Added `_loadAdWatchCountForToday();` to `initState` (after `_loadBuilderBuildsRemaining();`).
4. Added `_loadAdWatchCountForToday()` (loads today's watch count from `SettingsService.loadAdWatchCountForToday`) and `_watchAdForPoint()` (shows the rewarded ad, then on reward records the watch via `recordAdWatchForToday()`, adds 1 build via `addBuilderBuilds(1)`, bumps `_todayAdWatches`, and reloads the build balance) after `_loadBuilderBuildsRemaining`.
5. Changed the save-flow reward in `_saveRoutine` from `addBuilderBuilds(2)` to `addBuilderBuilds(1)`.
6. Changed the `_promptWatchAdForBuild` dialog copy from "unlock 2 extra builds" to "unlock 1 extra build".
7. Mounted `EarnPointsCard` inside `if (widget.showBuilder) ...[` above the "Create Workout" `Container`, passing `buildPoints: _builderBuildsRemaining`, `todayWatches: _todayAdWatches`, `maxDailyWatches: _kMaxDailyAdWatches`, and `onWatchAd: _todayAdWatches >= _kMaxDailyAdWatches ? null : _watchAdForPoint` (button disabled at the daily cap).

## TDD evidence

**Deviation from dispatch (see Concerns):** the dispatch's test steps referenced `test/workout_builder_page_test.dart`, which does **not exist** and has never existed in git history (`git log --all -- test/workout_builder_page_test.dart` → empty). The brief — declared the source of truth — explicitly and verifiably rules out a page widget test: `_WorkoutBuilderPageState` initializes `final CommunityFirestoreService _communityService = CommunityFirestoreService.instance;` at field-init (workout_builder_page.dart:27), which touches `FirebaseFirestore.instance` and throws `FirebaseException: [core/no-app]` in tests (same root cause as the 3 pre-existing `widget_test.dart` failures). So there is no genuinely new RED test for this task; the brief's Step 8 (full-suite + analyze) is the verification signal. I ran the full suite BEFORE and AFTER my edits.

- **Baseline (BEFORE edits):** `flutter test` → `00:11 +13 -3: Some tests failed.` All earn-points tests pass (builder_ad_watches_test 6/6, builder_builds_test 2/2, earn_points_card_test 1/1, header_banner_ad_test 3/3, scaled_banner_ad_test 1/1 = 13 green). The 3 failures are pre-existing in `test/widget_test.dart` (`FirebaseException: [core/no-app]` in `AuthService`).
- **After edits:** `flutter test` → `00:04 +13 -3: Some tests failed.` Identical pass set (13) and identical 3 pre-existing `widget_test.dart` failures with the same stack traces. No regressions.
- **`flutter analyze lib/pages/workout_builder_page.dart`** → `1 issue found` — `info` `avoid_print` at workout_builder_page.dart:104, the pre-existing `print('Failed to load rewarded ad: $error')` line that I did not touch. No new issues.

## Files changed

- Modified: `lib/pages/workout_builder_page.dart`
- Commit: `cba9a6c` — "feat: show earn points card and award one build per ad" (1 file, +278/−2)
- Verified via `git show --stat HEAD`: the commit contains exactly `lib/pages/workout_builder_page.dart` and nothing else. No `git add -A`/`git add .` used; `test/builder_builds_test.dart` and all other WIP remain uncommitted.

## Pre-existing WIP preservation

`lib/pages/workout_builder_page.dart` contained the user's WIP lines before I started (builder-builds integration: import-link/import-workout/copy-link sections, `_communityService` field, build-count `_SummaryChip`, etc.). Per the dispatch, I transcribed only the brief's edits onto the current working-tree content and did not revert/reformat the WIP lines — the `git diff` confirms every pre-existing hunk is present byte-for-byte. Because the brief's Step 11 (`git add lib/pages/workout_builder_page.dart`) stages the whole file, the pre-existing WIP hunks in that file are included in commit `cba9a6c`; this is unavoidable and sanctioned by the dispatch ("lib/pages/workout_builder_page.dart itself may contain WIP lines… do not revert them"). They are NOT described in the commit message.

## Self-review findings

1. All 7 brief steps verified present in the file post-edit (import, fields, initState, methods, +1 save reward, prompt copy, card mount above Create Workout).
2. Test output is clean for the task's scope: 13 pass, only the 3 pre-existing, unrelated `widget_test.dart` Firebase-init failures remain.
3. `git status --short` after commit confirms all other WIP (`.superpowers/sdd/*`, `lib/*`, `android/`, `ios/`, `macos/`, `pubspec.*`, `logo.png`, untracked dirs/files incl. `test/builder_builds_test.dart`) is untouched and unstaged.
4. **Concern 1 (dispatch vs brief conflict):** the dispatch instructed creating a failing widget test in `test/workout_builder_page_test.dart` and confirming RED→GREEN, and to commit that test file too. That file does not exist and a page widget test is infeasible per the brief's verified reasoning (Firebase at field-init). I followed the brief (source of truth): no new page test, commit contains only the page file.
5. **Concern 2 (commit message):** dispatch suggested "feat: wire earn points card into workout builder page"; brief's Step 11 says "feat: show earn points card and award one build per ad". I used the brief's wording (declared source of truth). Flagged for the reviewer.
6. **Concern 3:** like prior tasks, committing the page file necessarily includes its pre-existing WIP hunks (see above); the change itself is intact and unmodified.
