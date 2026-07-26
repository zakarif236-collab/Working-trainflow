# Task 2: Schedule Persistence in SettingsService

**Files:**
- Modify: `lib/services/settings_service.dart` (add 3 methods at end of class)

**Interfaces:**
- Consumes: `WorkoutSchedule` from Task 1
- Produces: `loadWorkoutSchedule()`, `saveWorkoutSchedule(WorkoutSchedule)`, `clearWorkoutSchedule()`

- [ ] **Step 1: Add import**

At top of `settings_service.dart`, add:
```dart
import 'package:my_app/models/workout_schedule.dart';
```

- [ ] **Step 2: Add schedule methods**

Add these methods inside the `SettingsService` class (before the closing brace):

```dart
  // --- Workout Schedule ---

  static const _scheduleKey = 'workout_schedule';

  Future<WorkoutSchedule> loadWorkoutSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduleKey);
    if (raw == null || raw.isEmpty) {
      return const WorkoutSchedule();
    }
    try {
      return WorkoutSchedule.decode(raw);
    } catch (_) {
      return const WorkoutSchedule();
    }
  }

  Future<void> saveWorkoutSchedule(WorkoutSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduleKey, schedule.encode());
  }

  Future<void> clearWorkoutSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduleKey);
  }
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/services/settings_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add workout schedule persistence to SettingsService"
```
