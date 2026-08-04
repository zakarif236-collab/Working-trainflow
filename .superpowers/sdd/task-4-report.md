# Task 4 Report: `resolveInsights` — DONE

## Status

**DONE** — committed as `e82d81b` ("feat: resolve insight scalars conflict-safely from session union").

## What I implemented

In `lib/services/settings_service.dart`, directly above `pickNewerInsights`:

- `DateTime? _later(DateTime? a, DateTime? b)` — later of two timestamps (null-safe).
- `WorkoutInsights resolveInsights(WorkoutInsights local, WorkoutInsights? remote, List<WorkoutSessionEntry> mergedSessions)`:
  - Profile fields (`displayName`, `bio`, `profileImagePath`) come from `pickNewerInsights(local, remote)`.
  - **Non-truncated** (`mergedSessions.length < _kSessionStorageCap`): `totalWorkouts` = union length, `totalSeconds` = sum of `durationSeconds`, streaks from `computeStreaks(mergedSessions)`, `lastWorkoutAt` = `mergedSessions.first.completedAt`.
  - **Truncated** (`length >= _kSessionStorageCap`): `totalWorkouts`/`totalSeconds`/`currentStreakDays`/`bestStreakDays` are the monotonic max of local/remote (never drops), `lastWorkoutAt` = `_later(local, remote)`.

In `test/workout_progress_sync_test.dart`: appended the two `resolveInsights` tests from the brief, with the union in the first test written descending (see adjudication below).

## Controller adjudication (plan-internal contradiction)

The brief's own Step 1 test used `union = [entry(1000), entry(2000), entry(3000), entry(4000)]` (ascending) while expecting `lastWorkoutAt == 4000`; the brief's verbatim implementation (`mergedSessions.first.completedAt`) yields `1000` on that order. The controller **approved Option B**: keep `resolveInsights` verbatim (including `mergedSessions.first.completedAt`) and change ONLY the test's union data to descending — `[entry(4000), entry(3000), entry(2000), entry(1000)]` — matching the documented interface contract that `mergedSessions` is the descending-sorted output of `mergeSessionsByTimestamp`. All assertions unchanged. `.first` on the descending union yields the newest session (4000).

## TDD evidence

### RED (expected, Step 2)
Command: `flutter test test/workout_progress_sync_test.dart --plain-name "resolveInsights"`
```
test/workout_progress_sync_test.dart:167:22: Error: Method not found: 'resolveInsights'.
test/workout_progress_sync_test.dart:199:22: Error: Method not found: 'resolveInsights'.
00:00 +0 -1: Some tests failed.
```

### RED (contradiction, pre-adjudication)
Verbatim code + verbatim ascending test:
```
00:00 +0 -1: resolveInsights recomputes counters from a complete union [E]
  Expected: DateTime:<1970-01-01 01:00:04.000>
    Actual: DateTime:<1970-01-01 01:00:01.000>
```
(truncated-path test passed; documented in the first version of this report.)

### GREEN (post-adjudication)
Command: `flutter test test/workout_progress_sync_test.dart`
```
00:00 +14: All tests passed!
```
All 14 tests pass (12 prior + 2 new `resolveInsights` tests).

### Analyze
Command: `flutter analyze` → 11 issues, all pre-existing `info` lints in OTHER files (`avoid_print` in community_page.dart, home_page.dart, workout_builder_page.dart, community_firestore_service.dart; `avoid_types_as_parameter_names` at community_firestore_service.dart:334-336). **No new issues in the two changed files.**

Note: the brief's verbatim fold used `(sum, s) => sum + s.durationSeconds`; `sum` collides with a visible type name and triggered `avoid_types_as_parameter_names` at settings_service.dart:1264. I renamed the accumulator to `(total, s)` — the only deliberate deviation from verbatim code, required to satisfy the "no new analyze issues" gate. Semantics unchanged.

## Files changed

- `lib/services/settings_service.dart` (committed): `_later`, `resolveInsights`.
- `test/workout_progress_sync_test.dart` (committed): two `resolveInsights` tests.
- `.superpowers/sdd/task-4-report.md` (tracked, left uncommitted per convention): this report.

Unrelated working-tree changes (audio_engine.dart, workout_schedule_section.dart, gradle caches, .superpowers/*.md, docs/plans, test/audio_engine_test.dart) were not touched, staged, or committed. Only the two named files were staged via explicit `git add <path>`.

## Self-review findings

- **Non-truncated recompute path:** counters/streaks recomputed from the union; `lastWorkoutAt` = newest (`.first`) — correct per the contract that the union is descending-sorted.
- **Truncated max path:** all four scalars are monotonic max of local/remote, never dropping below either source; `lastWorkoutAt` = `_later`. Covered by test.
- **Empty merged sessions:** non-truncated path returns `lastWorkoutAt: null`, counters 0, streaks (0,0). Handled by code; not covered by a test (pre-existing gap, acceptable).
- **lastWorkoutAt tie:** `_later` returns `b` (remote) on a tie; `pickNewerInsights` also prefers remote on a tie — consistent remote-favoring tie-break. Not covered by a test.

## Concerns

1. The one deviation from verbatim code: fold accumulator renamed `sum` → `total` to avoid a new analyzer lint. Semantically identical.
2. Minor pre-existing coverage gaps (empty-union recompute, timestamp tie-break) are not covered by tests; worth adding in a follow-up if desired.

## Commit

- `e82d81b` feat: resolve insight scalars conflict-safely from session union (2 files, +98)

## Report file

This file: `C:\Users\hp\my_app\.superpowers\sdd\task-4-report.md`
