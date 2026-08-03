# Multi-Device Sync Convergence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all devices converge to the same workout history and stats by merging remote sessions into local storage on read and resolving cumulative scalars from the merged session set.

**Architecture:** Pure, testable top-level functions (`mergeSessionsByTimestamp`, `computeStreaks`, `resolveInsights`) in `settings_service.dart` plus a thin `SettingsService.mergeRemoteInsights(uid)` orchestrator that unions local+remote sessions, persists the result to SharedPreferences, and returns merged insights for the Profile page. A shared `_kSessionStorageCap = 100` replaces all hardcoded `take(30)` sites. Separately, `firebase.json` gains a `firestore.rules` reference and the delete-rule admin email is replaced with an `admin: true` custom claim.

**Tech Stack:** Flutter/Dart, SharedPreferences, Cloud Firestore, Firebase CLI.

## Global Constraints

- Session storage cap = **100** (`const _kSessionStorageCap = 100`), used at every storage/sync site.
- UI display cap for recent sessions stays **7** (the `loadRecentSessions` default `limit`).
- Do **not** remove or reduce the existing 8s Firestore timeouts (`_kFirestoreNetworkTimeout`).
- Keep the existing best-effort pattern (try/catch + `debugPrint`) on Firestore paths.
- No new dependencies. Test with the existing `SharedPreferences.setMockInitialValues({})` pattern and pure functions only (no Firestore mocking available in this repo).
- **Manual step (not code):** the admin `admin: true` custom claim must be set once via Firebase Admin SDK before the updated rules are deployed.

---

### Task 1: Shared session cap constant (30 → 100)

**Files:**
- Modify: `lib/services/settings_service.dart` (const block; `recordWorkoutCompletion`, `loadRecentSessionsFromFirestore`, `syncWorkoutProgressToFirestore`, `sessionsToFirestoreMap`)
- Test: `test/workout_progress_sync_test.dart`

**Interfaces:**
- Produces: `const int _kSessionStorageCap = 100;` (private top-level, used by later tasks)

- [ ] **Step 1: Write the failing test (replace the old trim-to-30 test)**

In `test/workout_progress_sync_test.dart`, replace the test `'trims to the newest 30 sessions'` (lines 39-47) with:

```dart
  test('trims to the newest 100 sessions', () {
    final sessions = List.generate(105, (i) => entry(1000 + i));

    final map = sessionsToFirestoreMap(sessions);

    expect(map.length, 100);
    expect(map.keys.first, '1104');
    expect(map.keys.last, '1005');
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_progress_sync_test.dart --plain-name "trims to the newest 100 sessions"`
Expected: FAIL — `map.length` is 30, not 100.

- [ ] **Step 3: Add the cap constant**

In `lib/services/settings_service.dart`, near the existing top-level consts (after `const Duration _kFirestoreNetworkTimeout = Duration(seconds: 8);`), add:

```dart
const int _kSessionStorageCap = 100;
```

- [ ] **Step 4: Replace all five hardcoded `30` sites**

Site A — `recordWorkoutCompletion` (line ~1017), change:

```dart
    final recent = await loadRecentSessions(limit: 30);
```
to:
```dart
    final recent = await loadRecentSessions(limit: _kSessionStorageCap);
```

Site B — `recordWorkoutCompletion` (line ~1035), change:

```dart
    ].take(30).map((entry) => entry.toJson()).toList(growable: false);
```
to:
```dart
    ].take(_kSessionStorageCap).map((entry) => entry.toJson()).toList(growable: false);
```

Site C — `loadRecentSessionsFromFirestore` (line ~913), change:

```dart
      return sessions.take(30).toList(growable: false);
```
to:
```dart
      return sessions.take(_kSessionStorageCap).toList(growable: false);
```

Site D — `syncWorkoutProgressToFirestore` (line ~953), change:

```dart
      final sessions = await loadRecentSessions(limit: 30);
```
to:
```dart
      final sessions = await loadRecentSessions(limit: _kSessionStorageCap);
```

Site E — `sessionsToFirestoreMap` (line ~1176), change:

```dart
    for (final s in sorted.take(30))
```
to:
```dart
    for (final s in sorted.take(_kSessionStorageCap))
```

- [ ] **Step 5: Run the full sync test file to verify it passes**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: ALL PASS (updated trim test + existing tests).

- [ ] **Step 6: Run analyze**

Run: `flutter analyze`
Expected: no new issues in `settings_service.dart`.

- [ ] **Step 7: Commit**

```bash
git add lib/services/settings_service.dart test/workout_progress_sync_test.dart
git commit -m "feat: raise session storage cap to 100 via shared constant"
```

---

### Task 2: `mergeSessionsByTimestamp` (union, dedup, cap, ordering)

**Files:**
- Modify: `lib/services/settings_service.dart` (new top-level function near `sessionsToFirestoreMap`)
- Test: `test/workout_progress_sync_test.dart`

**Interfaces:**
- Produces: `List<WorkoutSessionEntry> mergeSessionsByTimestamp(List<WorkoutSessionEntry> local, List<WorkoutSessionEntry> remote)` — union keyed by `completedAt.millisecondsSinceEpoch`, deduped, sorted newest-first, capped at `_kSessionStorageCap`. Consumed by Task 5.

- [ ] **Step 1: Write the failing tests**

Append to `test/workout_progress_sync_test.dart` (inside `main()`):

```dart
  test('mergeSessionsByTimestamp unions and dedups by timestamp key', () {
    final local = [entry(1000), entry(2000), entry(2000)];
    final remote = [entry(2000), entry(3000)];

    final merged = mergeSessionsByTimestamp(local, remote);

    expect(merged.length, 3);
    expect(
      merged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
      [3000, 2000, 1000],
    );
  });

  test('mergeSessionsByTimestamp caps the union', () {
    final local = List.generate(60, (i) => entry(1000 + i));
    final remote = List.generate(60, (i) => entry(1_000_000 + i));

    final merged = mergeSessionsByTimestamp(local, remote);

    expect(merged.length, 100);
    expect(merged.first.completedAt.millisecondsSinceEpoch, 1_000_059);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/workout_progress_sync_test.dart --plain-name "mergeSessionsByTimestamp"`
Expected: FAIL — function not defined.

- [ ] **Step 3: Implement the function**

In `lib/services/settings_service.dart`, directly above `sessionsToFirestoreMap`, add:

```dart
List<WorkoutSessionEntry> mergeSessionsByTimestamp(
  List<WorkoutSessionEntry> local,
  List<WorkoutSessionEntry> remote,
) {
  final byKey = <int, WorkoutSessionEntry>{
    for (final s in [...local, ...remote]) s.completedAt.millisecondsSinceEpoch: s,
  };
  final merged = byKey.values.toList()
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return merged.take(_kSessionStorageCap).toList(growable: false);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/services/settings_service.dart test/workout_progress_sync_test.dart
git commit -m "feat: add timestamp-keyed session union merge"
```

---

### Task 3: `computeStreaks` + shared `_epochDayOf`

**Files:**
- Modify: `lib/services/settings_service.dart` (top-level helpers; delegate class `_epochDay`)
- Test: `test/workout_progress_sync_test.dart`

**Interfaces:**
- Produces: `int _epochDayOf(DateTime date)` (top-level); `(int current, int best) computeStreaks(List<WorkoutSessionEntry> sessions)` — `current` = streak ending at the most recent session day, `best` = longest consecutive run. Consumed by Task 4.

- [ ] **Step 1: Write the failing tests**

Append to `test/workout_progress_sync_test.dart`:

```dart
  test('computeStreaks counts consecutive days ending at the most recent', () {
    // Days 10, 9, 8, then a gap, then 5, 4.
    final sessions = [
      entry(DateTime(2026, 8, 4).millisecondsSinceEpoch),
      entry(DateTime(2026, 8, 3).millisecondsSinceEpoch),
      entry(DateTime(2026, 8, 2).millisecondsSinceEpoch),
      entry(DateTime(2026, 7, 30).millisecondsSinceEpoch),
      entry(DateTime(2026, 7, 29).millisecondsSinceEpoch),
    ];

    final (current, best) = computeStreaks(sessions);

    expect(current, 3); // Aug 4, 3, 2
    expect(best, 3);
  });

  test('computeStreaks handles single session and empty list', () {
    final (singleCurrent, singleBest) = computeStreaks([entry(1000)]);
    expect(singleCurrent, 1);
    expect(singleBest, 1);

    final (emptyCurrent, emptyBest) = computeStreaks(const []);
    expect(emptyCurrent, 0);
    expect(emptyBest, 0);
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/workout_progress_sync_test.dart --plain-name "computeStreaks"`
Expected: FAIL — function not defined.

- [ ] **Step 3: Implement the helpers**

Add a top-level day helper next to the other top-level functions:

```dart
int _epochDayOf(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
}
```

Add `computeStreaks` directly above `mergeSessionsByTimestamp`:

```dart
(int current, int best) computeStreaks(List<WorkoutSessionEntry> sessions) {
  final days = <int>{
    for (final s in sessions) _epochDayOf(s.completedAt),
  }.toList()
    ..sort((a, b) => b.compareTo(a));
  if (days.isEmpty) return (0, 0);

  var run = 1;
  var best = 1;
  var current = 1;
  var firstSegment = true;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1] - days[i] == 1) {
      run++;
    } else {
      if (run > best) best = run;
      if (firstSegment) {
        current = run; // streak ending at the most recent session day
        firstSegment = false;
      }
      run = 1;
    }
  }
  if (run > best) best = run;
  if (firstSegment) current = run; // no gaps: the whole list is the current streak
  return (current, best);
}
```

Replace the class `_epochDay` method (line ~1042) with a delegation so both share one implementation:

```dart
  int _epochDay(DateTime date) => _epochDayOf(date);
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: ALL PASS (new + existing).

- [ ] **Step 5: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_service.dart test/workout_progress_sync_test.dart
git commit -m "feat: add streak computation from session dates"
```

---

### Task 4: `resolveInsights` with truncation guard

**Files:**
- Modify: `lib/services/settings_service.dart` (top-level `resolveInsights`, `_later`)
- Test: `test/workout_progress_sync_test.dart`

**Interfaces:**
- Consumes: `computeStreaks`, `pickNewerInsights` (existing), `_kSessionStorageCap`.
- Produces: `WorkoutInsights resolveInsights(WorkoutInsights local, WorkoutInsights? remote, List<WorkoutSessionEntry> mergedSessions)`. Profile fields (`displayName`, `bio`, `profileImagePath`) from `pickNewerInsights(local, remote)`; when the union is NOT truncated (`mergedSessions.length < _kSessionStorageCap`) counters are recomputed from the union; when truncated, counters use monotonic `max(local, remote)` and the later `lastWorkoutAt`. Consumed by Task 5.

- [ ] **Step 1: Write the failing tests**

Append to `test/workout_progress_sync_test.dart`:

```dart
  test('resolveInsights recomputes counters from a complete union', () {
    final local = insightsAt(null, total: 2);
    final remote = insightsAt(DateTime(2026, 8, 4), total: 2);
    final union = [entry(1000), entry(2000), entry(3000), entry(4000)];

    final resolved = resolveInsights(local, remote, union);

    expect(resolved.totalWorkouts, 4);
    expect(resolved.totalSeconds, 120);
    expect(resolved.lastWorkoutAt, DateTime.fromMillisecondsSinceEpoch(4000));
    expect(resolved.displayName, 'Test'); // profile fields come from pickNewerInsights
  });

  test('resolveInsights falls back to monotonic max when truncated', () {
    final local = WorkoutInsights(
      displayName: 'Test',
      profileImagePath: '',
      bio: '',
      totalWorkouts: 150,
      totalSeconds: 9000,
      currentStreakDays: 30,
      bestStreakDays: 40,
      lastWorkoutAt: DateTime(2026, 8, 1),
    );
    final remote = WorkoutInsights(
      displayName: 'Test',
      profileImagePath: '',
      bio: '',
      totalWorkouts: 80,
      totalSeconds: 5000,
      currentStreakDays: 12,
      bestStreakDays: 20,
      lastWorkoutAt: DateTime(2026, 8, 2),
    );
    // Union is capped (length >= cap), so the list is incomplete.
    final union = List.generate(100, (i) => entry(1000 + i));

    final resolved = resolveInsights(local, remote, union);

    expect(resolved.totalWorkouts, 150); // max, never drops
    expect(resolved.totalSeconds, 9000);
    expect(resolved.currentStreakDays, 30);
    expect(resolved.bestStreakDays, 40);
    expect(resolved.lastWorkoutAt, DateTime(2026, 8, 2)); // later of the two
  });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/workout_progress_sync_test.dart --plain-name "resolveInsights"`
Expected: FAIL — function not defined.

- [ ] **Step 3: Implement `resolveInsights` and `_later`**

Directly above `pickNewerInsights` (line ~1198), add:

```dart
DateTime? _later(DateTime? a, DateTime? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.isAfter(b) ? a : b;
}

WorkoutInsights resolveInsights(
  WorkoutInsights local,
  WorkoutInsights? remote,
  List<WorkoutSessionEntry> mergedSessions,
) {
  final profile = pickNewerInsights(local, remote);
  final truncated = mergedSessions.length >= _kSessionStorageCap;

  if (!truncated) {
    final (currentStreak, bestStreak) = computeStreaks(mergedSessions);
    return WorkoutInsights(
      displayName: profile.displayName,
      profileImagePath: profile.profileImagePath,
      bio: profile.bio,
      totalWorkouts: mergedSessions.length,
      totalSeconds: mergedSessions.fold<int>(
          0, (sum, s) => sum + s.durationSeconds),
      currentStreakDays: currentStreak,
      bestStreakDays: bestStreak,
      lastWorkoutAt: mergedSessions.isEmpty
          ? null
          : mergedSessions.first.completedAt,
    );
  }

  final remoteCount = remote?.totalWorkouts ?? 0;
  return WorkoutInsights(
    displayName: profile.displayName,
    profileImagePath: profile.profileImagePath,
    bio: profile.bio,
    totalWorkouts: local.totalWorkouts > remoteCount
        ? local.totalWorkouts
        : remoteCount,
    totalSeconds: local.totalSeconds > (remote?.totalSeconds ?? 0)
        ? local.totalSeconds
        : (remote?.totalSeconds ?? 0),
    currentStreakDays: local.currentStreakDays > (remote?.currentStreakDays ?? 0)
        ? local.currentStreakDays
        : (remote?.currentStreakDays ?? 0),
    bestStreakDays: local.bestStreakDays > (remote?.bestStreakDays ?? 0)
        ? local.bestStreakDays
        : (remote?.bestStreakDays ?? 0),
    lastWorkoutAt: _later(local.lastWorkoutAt, remote?.lastWorkoutAt),
  );
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: ALL PASS.

- [ ] **Step 5: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_service.dart test/workout_progress_sync_test.dart
git commit -m "feat: resolve insight scalars conflict-safely from session union"
```

---

### Task 5: `mergeRemoteInsights` orchestrator + two-device converge test

**Files:**
- Modify: `lib/services/settings_service.dart` (`InsightsMergeResult` class; `SettingsService.mergeRemoteInsights`)
- Test: `test/workout_progress_sync_test.dart`

**Interfaces:**
- Consumes: `mergeSessionsByTimestamp`, `resolveInsights`, `loadInsights`, `loadRecentSessions(limit:)`, `loadInsightsFromFirestore`, `loadRecentSessionsFromFirestore`, prefs keys `_kRecentSessions`, `_kTotalWorkouts`, `_kTotalSeconds`, `_kCurrentStreakDays`, `_kBestStreakDays`, `_kLastWorkoutMillis`, `_kLastWorkoutEpochDay`.
- Produces: `class InsightsMergeResult { final WorkoutInsights insights; final List<WorkoutSessionEntry> sessions; }` and `Future<InsightsMergeResult> SettingsService.mergeRemoteInsights(String uid)`. Consumed by Task 6.

- [ ] **Step 1: Write the failing converge test**

Append to `test/workout_progress_sync_test.dart`:

```dart
  test('two devices offline, then converge to an identical union', () {
    // Device A's local history.
    final deviceA = [entry(1000), entry(2000)];
    // Device B's disjoint offline history.
    final deviceB = [entry(3000), entry(4000)];

    // A merges: its local sessions + the remote (B's) sessions.
    final aMerged = mergeSessionsByTimestamp(deviceA, deviceB);
    final aResolved = resolveInsights(
      insightsAt(null, total: 2),
      insightsAt(DateTime.fromMillisecondsSinceEpoch(4000), total: 2),
      aMerged,
    );

    // B merges: its local sessions + the remote (A's) sessions.
    final bMerged = mergeSessionsByTimestamp(deviceB, deviceA);
    final bResolved = resolveInsights(
      insightsAt(null, total: 2),
      insightsAt(DateTime.fromMillisecondsSinceEpoch(4000), total: 2),
      bMerged,
    );

    expect(aMerged.length, 4);
    expect(bMerged.length, 4);
    expect(aResolved.totalWorkouts, 4);
    expect(aResolved.totalSeconds, 120);
    // Both devices end up with the identical union.
    expect(
      bMerged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
      aMerged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
    );
    expect(bResolved.totalWorkouts, aResolved.totalWorkouts);
    expect(bResolved.totalSeconds, aResolved.totalSeconds);
  });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_progress_sync_test.dart --plain-name "two devices offline"`
Expected: PASS already (the pure functions exist from Tasks 2-4) — this is a regression guard. If it passes, note it and proceed.

- [ ] **Step 3: Add `InsightsMergeResult`**

In `lib/services/settings_service.dart`, near the top (after `const int _kSessionStorageCap = 100;`), add:

```dart
class InsightsMergeResult {
  const InsightsMergeResult({required this.insights, required this.sessions});

  final WorkoutInsights insights;
  final List<WorkoutSessionEntry> sessions;
}
```

- [ ] **Step 4: Implement `mergeRemoteInsights`**

Add to `SettingsService` (after `syncWorkoutProgressToFirestore`):

```dart
  Future<InsightsMergeResult> mergeRemoteInsights(String uid) async {
    final localInsights = await loadInsights();
    final localSessions = await loadRecentSessions(limit: _kSessionStorageCap);

    final remoteInsights = await loadInsightsFromFirestore(uid);
    final remoteSessions = await loadRecentSessionsFromFirestore(uid);

    final mergedSessions = mergeSessionsByTimestamp(localSessions, remoteSessions);
    final merged = resolveInsights(localInsights, remoteInsights, mergedSessions);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _kRecentSessions,
      jsonEncode(mergedSessions.map((e) => e.toJson()).toList(growable: false)),
    );
    await prefs.setInt(_kTotalWorkouts, merged.totalWorkouts);
    await prefs.setInt(_kTotalSeconds, merged.totalSeconds);
    await prefs.setInt(_kCurrentStreakDays, merged.currentStreakDays);
    await prefs.setInt(_kBestStreakDays, merged.bestStreakDays);
    if (merged.lastWorkoutAt != null) {
      await prefs.setInt(_kLastWorkoutMillis, merged.lastWorkoutAt!.millisecondsSinceEpoch);
      await prefs.setInt(_kLastWorkoutEpochDay, _epochDay(merged.lastWorkoutAt!));
    }

    return InsightsMergeResult(insights: merged, sessions: mergedSessions);
  }
```

- [ ] **Step 5: Run the sync test file**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: ALL PASS.

- [ ] **Step 6: Run analyze**

Run: `flutter analyze`
Expected: no new issues.

- [ ] **Step 7: Commit**

```bash
git add lib/services/settings_service.dart test/workout_progress_sync_test.dart
git commit -m "feat: add mergeRemoteInsights orchestrator that persists the union"
```

---

### Task 6: Profile page uses `mergeRemoteInsights`

**Files:**
- Modify: `lib/pages/first_page.dart` (online branch of `_loadInsights`)

**Interfaces:**
- Consumes: `SettingsService.mergeRemoteInsights(String uid)` → `InsightsMergeResult` (Task 5).
- Produces: Profile page renders and persists the merged union.

- [ ] **Step 1: Update the online branch**

In `lib/pages/first_page.dart`, replace the entire body of the online `if (ConnectivityService.instance.isOnline)` block (which currently reads remote insights and sessions separately) with:

```dart
      if (ConnectivityService.instance.isOnline) {
        try {
          final result = await _settingsService
              .mergeRemoteInsights(uid)
              .timeout(_kInsightsNetworkTimeout);
          if (!mounted) {
            return;
          }
          setState(() {
            _insights = result.insights;
            _recentSessions = result.sessions;
          });
        } catch (_) {
          // Offline or slow network: keep the local data already shown.
        }
      }
```

- [ ] **Step 2: Run analyze and tests**

Run: `flutter analyze` then `flutter test test/workout_progress_sync_test.dart`
Expected: no new issues; ALL PASS.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/first_page.dart
git commit -m "feat: profile page renders and persists the merged sync union"
```

---

### Task 7: Wire Firestore rules into deploy; parameterize admin authorization

**Files:**
- Modify: `firebase.json`
- Modify: `firestore.rules`

**Interfaces:**
- Produces: `firebase deploy --only firestore:rules` pushes `firestore.rules`; community-workout delete requires `request.auth.token.admin == true`.

- [ ] **Step 1: Add the rules reference to `firebase.json`**

Replace the entire one-line `firebase.json` with:

```json
{"flutter":{"platforms":{"android":{"default":{"projectId":"video-helper-21817","appId":"1:832592716654:android:11ec55736f9e676665577f","fileOutput":"android/app/google-services.json"}},"dart":{"lib/firebase_options.dart":{"projectId":"video-helper-21817","configurations":{"android":"1:832592716654:android:11ec55736f9e676665577f","ios":"1:832592716654:ios:ac715fa0b6bd8a6365577f","macos":"1:832592716654:ios:ac715fa0b6bd8a6365577f","web":"1:832592716654:web:20a5212b50d8da4a65577f","windows":"1:832592716654:web:ef4d41d6988f5f1b65577f"}}}},"firestore":{"rules":"firestore.rules"}}
```

- [ ] **Step 2: Replace the admin email with a custom claim in `firestore.rules`**

In `firestore.rules`, replace the delete rule (lines 24-26):

```
      allow delete: if request.auth != null &&
          (resource.data.creatorId == request.auth.uid ||
           request.auth.token.email == 'kingslayer.et@gmail.com');
```

with:

```
      allow delete: if request.auth != null &&
          (resource.data.creatorId == request.auth.uid ||
           request.auth.token.admin == true);
```

- [ ] **Step 3: Validate the JSON**

Run: `node -e "JSON.parse(require('fs').readFileSync('firebase.json','utf8')); console.log('valid json')"`
Expected: `valid json`

- [ ] **Step 4: Commit**

```bash
git add firebase.json firestore.rules
git commit -m "chore: wire firestore rules into deploy and use admin custom claim"
```

- [ ] **Step 5: Manual checklist (document for the user, do not run)**

1. Set the admin claim once: `firebase` Admin SDK `setCustomUserClaims('<admin-uid>', {admin: true})`.
2. Deploy: `firebase deploy --only firestore:rules`.
3. Verify a community-workout delete still works for the admin and still fails for non-admins.

---

### Task 8: Full-suite verification

- [ ] **Step 1: Run the complete test suite**

Run: `flutter test`
Expected: same result as baseline (existing 3 pre-existing `widget_test.dart` timer failures may remain; `workout_progress_sync_test.dart` must be ALL PASS).

- [ ] **Step 2: Run analyze**

Run: `flutter analyze`
Expected: no new issues introduced by this plan.

- [ ] **Step 3: Manual smoke test**

- Complete a workout on device A offline, then on device B offline (same account). Sync both. Verify Profile on each shows the union and correct totals.
- Kill and reopen one device offline — Profile still renders from local prefs (no hang).
- Reconnect — Profile converges to the union.

- [ ] **Step 4: Update progress doc**

Append results to `.superpowers/sdd/progress.md`.
