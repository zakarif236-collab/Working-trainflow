# Workout Reminder Settings Inline in Activity Tab

Date: 2026-08-03

## Problem

The workout reminder settings currently live behind a small calendar icon in the
Activity tab's app bar. Tapping it opens a whole separate page
(`WorkoutSchedulePage`). Users want the reminder/notification settings visible
immediately when they open the Activity tab — no small icon, no separate page.

## Goal

Clicking the Activity tab shows the workout reminder settings right away at the
top of the page, with the notification feed below it. Everything is on one
screen.

## Current State

- `lib/pages/notifications_page.dart` — Activity tab. App bar has a calendar
  icon that pushes `WorkoutSchedulePage`. Body shows the in-app notification
  feed (likes/follows/comments/downloads/achievements) or an empty state.
- `lib/pages/workout_schedule_page.dart` — full-screen schedule editor:
  enable toggle, day picker (Mon–Sun), time picker, frequency slider, and a
  schedule summary. Owns its own `SettingsService`/`ReminderService` calls.
  Only referenced from `notifications_page.dart`.

## Design

### 1. New reusable widget: `lib/widgets/workout_schedule_section.dart`

Extract the schedule editor UI and state from `WorkoutSchedulePage` into a
self-contained stateful widget `WorkoutScheduleSection`:

- Owns `SettingsService` and `WorkoutSchedule` state, and the existing save +
  `ReminderService.scheduleWeeklyNotifications(...)` flow.
- Renders, top to bottom:
  - "Workout Reminders" card with the enable switch.
  - When enabled: the day picker, time picker, frequency slider, and schedule
    summary (same visuals as the current schedule page).
  - When toggled on from off: sends the schedule confirmation notification
    (reuses `sendScheduleConfirmation`).
- Reuses the existing `_Card` styling and dark-theme colors.

No behavior change to scheduling — weekly reminders still fire at the user's
chosen days/time, and the once-per-day missed-workout reminder is untouched.

### 2. Embed at top of Activity tab

Restructure `NotificationsPage` body into:

- A `WorkoutScheduleSection` pinned at the top (always visible on load).
- The notification feed below it in an `Expanded` `ListView`.

Empty state: when there are no notifications, the section still shows at top
and the existing "No activity yet" message appears below it.

### 3. Remove the separate page

- Delete the calendar icon from the Activity app bar.
- Delete `lib/pages/workout_schedule_page.dart` (no longer referenced).

## Files

| File | Change |
| --- | --- |
| `lib/widgets/workout_schedule_section.dart` | New — extracted schedule editor widget |
| `lib/pages/notifications_page.dart` | Embed section at top; remove calendar icon and navigation |
| `lib/pages/workout_schedule_page.dart` | Deleted |

## Testing

- `flutter analyze` clean.
- Existing widget tests still pass.
- Manual: Activity tab shows reminder settings at top; toggling on expands the
  day/time/frequency controls; schedule confirmation notification appears;
  notification feed renders below.
