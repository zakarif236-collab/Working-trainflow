# Foreground Notification Gating — Design Spec

## Goal
The workout timer's companion Pause/Stop notification must appear only while the app is backgrounded or the phone is locked — never while the user is actively inside the app. Today it pops up ~1s after the timer starts.

## Root Cause
`WorkoutForegroundService` already runs the service in background mode (`isForegroundMode: false`) and only promotes to foreground on `AppLifecycleState.paused`. However, `update()` posts the companion action notification (id 889) unconditionally whenever the service is running and the platform is Android (`lib/services/workout_foreground_service.dart:162-167`). The timer controller fires `notifyListeners()` every tick, so the first `update()` — roughly one second after tapping Start — posts the notification even though the service was never promoted to foreground.

## Architecture
Single change in `lib/services/workout_foreground_service.dart`. The promote/demote lifecycle already gates the plugin's own foreground notification; this fix extends the same gating to the companion action notification.

## Components

| Component | File | Purpose |
|-----------|------|---------|
| WorkoutForegroundService | `lib/services/workout_foreground_service.dart` | Add `_isForegrounded` flag; gate `_showActionNotification` on it |

## Change
1. Add `bool _isForegrounded = false;` — true only while the companion notification is visible.
2. `start()`: reset `_isForegrounded = false` for a fresh session.
3. `promoteToForeground()`: set `_isForegrounded = true` before showing the action notification.
4. `demoteToBackground()`: set `_isForegrounded = false` and cancel the action notification.
5. `stop()`: reset `_isForegrounded = false`.
6. `update()`: call `_showActionNotification()` only when `_isForegrounded` is true. `_updateForegroundNotificationInfo()` stays unconditional — the native side already ignores it when not in foreground mode.

## Data Flow
1. Timer starts → service runs in background mode, no notification.
2. User backgrounds/locks app → `promoteToForeground()` sets flag and shows notification (content already fresh from ongoing `update()` calls).
3. Timer ticks in background → `update()` refreshes the visible notification (dedupe intact).
4. User resumes → `demoteToBackground()` hides notification and clears flag.
5. Workout ends → `stop()` clears notification and flag.

## Edge Cases
- Restart after prior session: flag reset in `start()`/`stop()`.
- Backgrounded updates: still refresh the visible notification.
- Resume: notification removed.
- Applies to both timer pages (`workout_timer_page.dart`, `workout_builder_player_page.dart`) since they share the singleton.
- Pre-existing race (backgrounding before `start()` finishes) is out of scope; behavior unchanged by this fix.

## Testing
No unit test added: the service is coupled to platform channels and mocking would add brittle harness for a 4-line gating change. Verify by building the debug APK and manually checking: no notification in-app, notification on background, removal on resume.
