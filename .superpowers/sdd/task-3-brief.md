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

