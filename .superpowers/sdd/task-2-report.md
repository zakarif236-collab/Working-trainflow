# Task 2 Report: `EarnPointsCard` widget

## Status: DONE

## What I implemented

`lib/widgets/earn_points_card.dart` — a `const EarnPointsCard({super.key, required int buildPoints, required int todayWatches, required int maxDailyWatches, required VoidCallback? onWatchAd})` StatelessWidget, transcribed verbatim from the brief. Renders:
- Card styling matching the builder page (white `0.06` alpha fill, radius 16, `Colors.white24` border)
- "Earn Points" title
- Balance line ("N build points", singular handled)
- Daily progress ("2/5 today")
- Full-width "Watch Ad (+1)" `FilledButton.icon`, disabled when `onWatchAd` is null
- Helper copy

`test/earn_points_card_test.dart` — verbatim from the brief; 3 widget tests (content rendering, disabled-at-cap, tap-invokes-callback).

## TDD evidence

### RED
Command: `flutter test test/earn_points_card_test.dart`

Failing output (excerpt):
```
test/earn_points_card_test.dart:3:8: Error: Error when reading 'lib/widgets/earn_points_card.dart': The system cannot find the file specified
...
00:00 +0 -1: Some tests failed.
```

### GREEN
Command: `flutter test test/earn_points_card_test.dart`

Passing output:
```
00:00 +0: shows balance, daily progress, and helper copy
00:01 +1: watch button is disabled when the daily cap is reached
00:01 +2: tapping Watch Ad invokes the callback
00:01 +3: All tests passed!
```

## Files changed

- Created: `lib/widgets/earn_points_card.dart`
- Created: `test/earn_points_card_test.dart`
- Commit: `66303f3` — "feat: add earn points card widget" (2 files, +133)

## Self-review findings

1. Both files transcribed verbatim from the brief; no deviations needed (conventions confirmed: `Colors.white.withValues(alpha: 0.06)` used across `lib/widgets`, `FilledButton.icon` in use).
2. Commit verified via `git show --stat HEAD`: contains exactly the two task files (133 insertions). All unrelated WIP changes remain unstaged/uncommitted.
3. Test output clean: `All tests passed!` (3 tests). Only note: Git's standard LF→CRLF warning on add; harmless.
4. `lib/widgets/` already existed; `earn_points_card.dart` did not.

## Concerns

- None.
