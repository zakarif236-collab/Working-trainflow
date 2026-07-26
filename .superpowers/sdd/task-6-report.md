## Task 6 Report: Wire up weekly notification scheduling on app start

**Status:** Complete

**Commit:** `9a4f5a1` — `feat: wire up weekly notification scheduling on app start`

**Changes:**
- Added `import 'package:my_app/models/workout_schedule.dart';` to `lib/pages/main_shell_page.dart`
- In `_scheduleDailyNotification()`, added code after the existing daily motivation call to load the saved `WorkoutSchedule` via `SettingsService().loadWorkoutSchedule()` and re-schedule weekly notifications via `ReminderService.instance.scheduleWeeklyNotifications(schedule)` when enabled and non-empty

**Test summary:** `flutter analyze lib/pages/main_shell_page.dart` passes with 1 warning (unused import for `workout_schedule.dart` — type is inferred, import kept per spec).

**Concerns:**
- The `workout_schedule.dart` import triggers an `unused_import` warning because `WorkoutSchedule` is inferred but never explicitly referenced. This is cosmetic but will surface in CI lint checks if `avoid_unused_imports` is enforced.
- No unit test covers the re-scheduling path in `_scheduleDailyNotification()`; the try/catch silently swallows errors, making failures invisible at runtime.
