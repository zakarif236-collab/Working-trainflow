# Sync Workout Progress to Firestore After Each Workout

Date: 2026-08-03

## Problem

Workout progress (totals, streak, session history) is stored only in local
SharedPreferences. It is synced to Firestore only when the user edits their
profile. A user who signs in with Google (or later upgrades an anonymous
account to Google) and gets a new device cannot restore their workout history.

## Goal

After each completed workout, sync the user's progress — summary stats and the
recent session history — to their Firestore `users/{uid}` document, and restore
it on the Profile page when loading.

## Current State

- `settings_service.dart` `recordWorkoutCompletion()` — updates local prefs only
  (totals, streak, last workout, recent sessions).
- `saveInsightsToFirestore(uid, insights)` — writes `users/{uid}` with profile +
  stats; called only from the profile-edit flow (`first_page.dart:163`).
- `loadInsightsFromFirestore(uid)` — reads `users/{uid}`; called on Profile load
  and overrides local insights when present.
- `loadRecentSessions({limit})` — reads only from local prefs.

## Design

### 1. Sync after each workout

At the end of `recordWorkoutCompletion()`, after the local prefs update, perform
a best-effort Firestore write to `users/{uid}` using `set(..., merge: true)`:

```text
totalWorkouts, totalSeconds, currentStreakDays, bestStreakDays,
lastWorkoutAt, recentSessions (last 30 entries), updatedAt
```

Gating: only when there is a real Firebase session
(`FirebaseAuth.instance.currentUser?.uid != null`). Offline device-UID users are
skipped so no junk docs are created. Failures are swallowed with a debug log,
matching the existing best-effort pattern.

The write is merged so it never clobbers `displayName`, `bio`, or
`profileImagePath`.

### 2. Include session history in profile saves

Extend `saveInsightsToFirestore(uid, insights)` to also write `recentSessions`
(loaded via `loadRecentSessions(limit: 30)`) so the profile-edit sync and the
post-workout sync keep the same shape.

### 3. Restore history on Profile load

- Add `loadRecentSessionsFromFirestore(String uid)` to read the
  `recentSessions` array from `users/{uid}` into
  `List<WorkoutSessionEntry>`.
- In `first_page.dart` `_loadInsights()`, load recent sessions from Firestore
  first and fall back to local prefs when Firestore has none (new device).

## Files

| File | Change |
| --- | --- |
| `lib/services/settings_service.dart` | Sync in `recordWorkoutCompletion`; extend `saveInsightsToFirestore`; add `loadRecentSessionsFromFirestore` |
| `lib/pages/first_page.dart` | Load recent sessions from Firestore first, local fallback |

## Assumptions

- Firestore security rules permit a user to read/write their own `users/{uid}`
  doc. Rules are not in the repo; the existing profile-edit sync already uses
  this path.

## Testing

- `flutter analyze` clean; existing tests still pass.
- Manual: complete a workout on device A (signed in) → verify `users/{uid}`
  doc in Firestore has fresh `totalWorkouts`/`recentSessions` → on a new device
  signed in with the same account, Profile shows restored stats and history.
