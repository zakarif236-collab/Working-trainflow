# Design: Navigation Fix + Daily Motivation Notification

## Problem 1: Quick Start training stuck on previous session

**Bug:** `MainShellPage` uses `IndexedStack` with 3 tabs. HomeTimerPage (index 0) wraps `WorkoutTimerPage`. When user clicks Quick Start → VO2max from the Mods tab (index 1), a *second* `WorkoutTimerPage` is pushed via `Navigator.pushNamed('/workout', ...)`. When user goes back, they return to the Mods tab, and the Home tab's `WorkoutTimerPage` is still alive with stale state from before — "stuck on previous training."

**Fix:** Eliminate the duplicate route. Instead of pushing a new `WorkoutTimerPage`, switch to the timer tab (index 0) and pass the new `WorkoutConfig` directly.

### Changes

1. **`main_shell_page.dart`** — Add `_pendingWorkoutConfig` and `_switchToTimerWithConfig(WorkoutConfig)` method. Pass this as a callback to `HomePage` via constructor.

2. **`home_page.dart`** — Accept an `onStartTraining` callback. In `_openTrainingLauncher`, instead of `Navigator.pushNamed('/workout', ...)`, call the callback with the preset config. This switches to timer tab with the config.

3. **`home_timer_page.dart`** — Accept optional `WorkoutConfig?` parameter. Forward it to `WorkoutTimerPage` as route arguments.

4. **`main.dart`** — No route changes needed (the `/workout` route stays for other callers). The `MainShellPage` passes the config to `HomeTimerPage` via its widget tree.

---

## Problem 2: Daily morning notification

**Feature:** Add a creative daily notification at 8:00 AM to motivate users to train. Messages are streak-aware and varied.

### Changes

1. **`reminder_service.dart`** — Add `scheduleDailyMotivation(SettingsService)`:
   - Reads streak from `SettingsService.loadInsights()`
   - Picks a random message from a streak-based pool
   - Uses `zonedSchedule` with `matchDateTimeComponents: DateTimeComponents.time` for 8:00 AM daily
   - Re-schedules on each app launch to keep messages fresh

2. **Message pool** — 10-12 creative lines grouped by streak:
   - 0 days: "New day, new you. Your next workout is waiting."
   - 1-3 days: "You're building momentum. Don't stop now!"
   - 4-7 days: "{streak}-day streak! You're becoming unstoppable."
   - 8+ days: "{streak} days straight. You're a machine. Keep crushing it!"
   - Generic rotation: "Champions train when they don't feel like it.", "Your future self will thank you for showing up today.", etc.

3. **`main.dart`** — Call `ReminderService.instance.scheduleDailyMotivation(settingsService)` in `main()` or first page init.
