# Task 1 Report: Swap production interstitial IDs

## What I implemented

Updated `lib/add/ad_helper.dart` so the two interstitial cases of `AdHelper.adUnitIdFor` return the new production interstitial unit `ca-app-pub-3222893031015336/1741873338` (new AdMob account) when `production` is true, while keeping the Google test IDs when `production` is false.

Replaced:
```dart
case (AdPlatform.android, AdType.interstitial):
  // TODO(ads): add production interstitial IDs
  return 'ca-app-pub-3940256099942544/1033173712';
case (AdPlatform.ios, AdType.interstitial):
  // TODO(ads): add production interstitial IDs
  return 'ca-app-pub-3940256099942544/4411468910';
```

With:
```dart
case (AdPlatform.android, AdType.interstitial):
  return production
      ? 'ca-app-pub-3222893031015336/1741873338'
      : 'ca-app-pub-3940256099942544/1033173712';
case (AdPlatform.ios, AdType.interstitial):
  return production
      ? 'ca-app-pub-3222893031015336/1741873338'
      : 'ca-app-pub-3940256099942544/4411468910';
```

Exact values taken verbatim from the task brief. No other ad IDs, the App ID, or the rewarded IDs were touched (rewarded still intentionally points at the old account `6138624088986178`).

## What I tested and test results

- **Focused test** (`flutter test test/ad_helper_test.dart`): 3/3 PASS.
- **Full suite** (`flutter test`): 55 pass, 3 fail. The 3 failures are in `test/widget_test.dart` (pending-timer assertion: "A Timer is still pending even after the widget tree was disposed", originating from `_FirstPageState._loadInsights` / `SettingsService.loadInsightsFromFirestore`). I verified these are **pre-existing and unrelated**: I stashed my two-file change, re-ran `test/widget_test.dart` on the clean tree, and got the identical 3 failures, then popped the stash.
- **Analyzer** (`flutter analyze`): 17 issues found, all pre-existing in other files / `third_party`. **Zero** issues in `lib/add/ad_helper.dart` or `test/ad_helper_test.dart`.

## TDD Evidence

**RED** — after updating only the test (Step 1), `flutter test test/ad_helper_test.dart` failed as expected:

```
00:00 +1 -1: AdHelper.adUnitIdFor uses production IDs when production is true [E]
  Expected: 'ca-app-pub-3222893031015336/1741873338'
    Actual: 'ca-app-pub-3940256099942544/1033173712'
     Which: is different.
            Expected: ... -app-pub-32228930310 ...
              Actual: ... -app-pub-39402560999 ...
                                    ^
             Differ at offset 12
```

Why expected: the production code still returned the old Google test ID for interstitial while the test now asserts the new production unit — exactly the failure the brief predicted (Android case; iOS would fail identically once past the first assert).

**GREEN** — after implementing the `ad_helper.dart` change, same command passed:

```
00:00 +3: All tests passed!
```

## Files changed

- `lib/add/ad_helper.dart` (interstitial cases only, lines 69-76)
- `test/ad_helper_test.dart` (production interstitial expectations, lines 48-57)

## Self-review findings

- Only the two `TODO(ads)` interstitial cases changed; banner and rewarded cases byte-identical to before. ✓
- Debug (`production: false`) interstitial IDs unchanged — Google test IDs preserved. ✓
- Values match the brief exactly: `ca-app-pub-3222893031015336/1741873338`. ✓
- No App ID or other ad-unit changes in the diff. ✓
- Commit contains only the 2 intended files (other working-tree modifications — `.superpowers/sdd/*`, generated plugin registrant files — were pre-existing and left alone). ✓

## Issues or concerns

- None with the task itself. The 3 `widget_test.dart` failures are pre-existing flaky/pending-timer failures (Firestore insights) unrelated to this change; flagged for awareness but out of scope for Task 1.
