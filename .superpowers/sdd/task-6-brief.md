### Task 6: Model + SyncQueue + SettingsService — Utility Changes

**Files:**
- Modify: `lib/models/workout_models.dart`
- Modify: `lib/services/sync_queue.dart`
- Modify: `lib/services/settings_service.dart`

**Interfaces:**
- Produces: `WorkoutBuilderRoutine.fingerprint` (String), `SyncQueue.clear()`, `SettingsService.deduplicateWorkoutRoutines()`

**Changes:**

1. In `lib/models/workout_models.dart`, add `fingerprint` getter to `WorkoutBuilderRoutine` class. Place it after `estimatedDurationSeconds` and before `copyWith`:

```dart
String get fingerprint {
  final buffer = StringBuffer(name.trim().toLowerCase());
  for (final exercise in exercises) {
    buffer.write('|${exercise.name.trim().toLowerCase()}');
    buffer.write(':${exercise.workSeconds}:${exercise.restSeconds}');
  }
  return buffer.toString();
}
```

2. In `lib/services/sync_queue.dart`, add `clear()` method after `processQueue` and before `_execute`:

```dart
Future<void> clear() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_queueKey);
}
```

3. In `lib/services/settings_service.dart`, add `deduplicateWorkoutRoutines()` method. Place it near the end of the class, before the closing brace (after `clearWorkoutSchedule` or any existing method):

```dart
Future<void> deduplicateWorkoutRoutines() async {
  final routines = await loadWorkoutBuilderRoutines();
  if (routines.length < 2) return;
  final seen = <String>{};
  final deduped = <WorkoutBuilderRoutine>[];
  for (final routine in routines) {
    if (seen.add(routine.fingerprint)) {
      deduped.add(routine);
    }
  }
  if (deduped.length == routines.length) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kWorkoutBuilderRoutines,
    jsonEncode(deduped.map((e) => e.toJson()).toList()),
  );
}
```

Run `dart analyze lib/models/workout_models.dart lib/services/sync_queue.dart lib/services/settings_service.dart`
Commit: `feat: add fingerprint, clear(), and dedup helpers`
