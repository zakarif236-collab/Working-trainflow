# Workout Notification Service — Design Spec

## Goal
Professional persistent notification for all timer modes with foreground service, action buttons, and background timer survival.

## Architecture
Foreground service via `flutter_background_service` runs timer in background isolate. Notification shows workout info + action buttons. MethodChannel communicates between notification actions and timer.

## Components

| Component | File | Purpose |
|-----------|------|---------|
| WorkoutForegroundService | `lib/services/workout_foreground_service.dart` | Foreground service, notification, background timer |
| WorkoutNotificationActions | `lib/services/workout_notification_actions.dart` | Routes notification taps to correct timer |
| AndroidManifest.xml | `android/app/src/main/AndroidManifest.xml` | FOREGROUND_SERVICE + WAKE_LOCK permissions |
| pubspec.yaml | `pubspec.yaml` | Add flutter_background_service packages |

## Notification Layout
```
┌─────────────────────────────────────┐
│ 🏋️ Workout in Progress             │
│ Push-ups • Set 2/3 • 0:35          │
│ ▶️ Pause  ⏭ Skip  ⏹ Stop  🎵 Music │
└─────────────────────────────────────┘
```

## Data Flow
1. Timer page starts → calls `WorkoutForegroundService.start(config)`
2. Service creates foreground notification with action buttons
3. Timer ticks in background isolate → updates notification every second
4. Notification actions → MethodChannel → service → timer/music
5. Workout ends → service stops → notification removed

## Design Tokens
- Accent: `Color(0xFFFF8A1E)`
- Channel: `workout_foreground` / `Workout Timer`
- Icon: `@mipmap/ic_launcher`
