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

