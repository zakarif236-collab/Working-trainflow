# Task 1 Report: Swap production rewarded IDs

**Status:** DONE
**Commit:** `ed37918` — feat(ads): use new production rewarded ad unit IDs
**Date:** 2026-08-15

## What I implemented

Replaced the two production rewarded ad unit IDs in `lib/add/ad_helper.dart` (the `(AdPlatform.android, AdType.rewarded)` and `(AdPlatform.ios, AdType.rewarded)` switch cases) so production returns `ca-app-pub-3222893031015336/4804623122` instead of the old account's `ca-app-pub-6138624088986178/2840036851` (Android) and `ca-app-pub-6138624088986178/7209425656` (iOS). Debug (`production: false`) behavior is unchanged — Google test IDs retained. No other cases (App ID, banner, interstitial) were touched, and `workout_builder_page.dart` was not modified.

## What I tested and test results

- `flutter test test/ad_helper_test.dart` → all 3 tests pass (`00:00 +3: All tests passed!`).
- `flutter analyze` → no issues reported in `lib/add/ad_helper.dart` or `test/ad_helper_test.dart`. (17 pre-existing issues remain elsewhere: `third_party/flutter_tts` errors and `avoid_print`/type-name lints in unrelated files.)

## TDD Evidence

### RED — before implementation

Updated `test/ad_helper_test.dart` expectations first (both production rewarded expectations now assert `ca-app-pub-3222893031015336/4804623122`), then ran:

```
00:00 +1 -1: AdHelper.adUnitIdFor uses production IDs when production is true [E]
  Expected: 'ca-app-pub-3222893031015336/4804623122'
    Actual: 'ca-app-pub-6138624088986178/2840036851'
     Which: is different.
            Expected: ... a-app-pub-3222893031 ...
              Actual: ... a-app-pub-6138624088 ...
                                    ^
             Differ at offset 11

00:00 +2 -1: Some tests failed.
Failing tests:
  ... ad_helper_test.dart: AdHelper.adUnitIdFor uses production IDs when production is true
```

Why expected: production code still returned the old account's rewarded unit for Android; the new expectation was added before implementation per TDD, so the test correctly failed on the first (Android) rewarded assertion.

### GREEN — after implementation

Updated the two rewarded cases in `ad_helper.dart`, then ran:

```
00:00 +1: AdHelper.adUnitIdFor uses Google test IDs when production is false
00:00 +2: AdHelper.adUnitIdFor uses production IDs when production is true
00:00 +3: AdHelper.adUnitIdFor public getters throw UnsupportedError on unsupported platforms
00:00 +3: All tests passed!
```

## Files changed

- `lib/add/ad_helper.dart` — 2 production rewarded ternaries updated to `ca-app-pub-3222893031015336/4804623122` (Android + iOS); debug test IDs unchanged.
- `test/ad_helper_test.dart` — 2 production rewarded expectations updated to `ca-app-pub-3222893031015336/4804623122`.

## Self-review findings

- Diff is minimal: only the two rewarded cases and the two corresponding test expectations changed; verified `git show HEAD` lists exactly `lib/add/ad_helper.dart` and `test/ad_helper_test.dart`.
- No remaining references to the old publisher prefix `6138624088986178` anywhere in `*.dart` files (grep confirmed).
- Banner/interstitial production IDs and the App ID were not touched.
- `workout_builder_page.dart` consumes `AdHelper.rewardedAdUnitId` unchanged via `_loadRewardedAd` (not in the diff).
- The `switch` is exhaustive and returns `String` in all cases, so no analyzer complaints.
- Working tree still shows unrelated modifications (SDD bookkeeping, generated plugin registrant files from running `flutter`); these were intentionally not committed as they are outside this task's scope.

## Issues / concerns

None. Note for downstream verification (Task 2): the old publisher prefix `6138624088986178` now appears nowhere in Dart source, which is a good cross-check.
