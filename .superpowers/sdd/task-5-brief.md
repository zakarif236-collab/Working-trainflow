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

