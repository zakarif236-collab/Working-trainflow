# Task 1 Report: `SettingsService` — daily ad-watch persistence

## Status: DONE

## What I implemented
Transcribed verbatim from the brief into `lib/services/settings_service.dart`:
- `Future<int> loadAdWatchCountForToday({DateTime? now})` — returns the count of rewarded ads watched today; 0 when nothing is stored, when the stored date is stale, or on corrupt JSON.
- `Future<void> recordAdWatchForToday({DateTime? now})` — increments today's count, reading the current count via `loadAdWatchCountForToday`.
- `String _dateKey(DateTime date)` helper (added after `_epochDay`).
- `const _kBuilderAdWatches = 'builder.adWatches';` constant (added after `_kBuilderBuildsInitialized`).

Created `test/builder_ad_watches_test.dart` verbatim from the brief (6 tests).

## TDD Evidence

### RED
Command: `flutter test test/builder_ad_watches_test.dart`
Result: FAIL (compile error) — first error:
```
test/builder_ad_watches_test.dart:12:27: Error: The method 'loadAdWatchCountForToday' isn't defined for the type 'SettingsService'.
```
Compilation failed with 9 errors (methods undefined) before implementation.

### GREEN
Command: `flutter test test/builder_ad_watches_test.dart`
Result: PASS — all 6 tests:
```
00:00 +6: All tests passed!
```

## Files changed
- `lib/services/settings_service.dart` (modified)
- `test/builder_ad_watches_test.dart` (new)

## Commit
- SHA: `eaac52c` (eaac52c2704d3103044ecfcef1b56c07fd3856ab)
- Subject: `feat: track daily rewarded ad watches in settings service`
- `git show --stat HEAD` confirms exactly 2 files, 132 insertions. No other WIP files staged.

## Self-review findings
- Insertions verified against the brief line-for-line; all three match verbatim.
- Test file verified against the brief verbatim.
- The working tree's unrelated WIP changes were left untouched (only the two named files were staged).
