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
lastWorkoutAt, recentSessions, updatedAt
```

The `recentSessions` array is trimmed to the last 30 entries before writing (the
local list is already bounded via `.take(30)`), so the doc never grows unbounded.
The write is a single merged document write and is therefore atomic — no batch
or transaction is needed.

Gating: only when there is a real Firebase session
(`FirebaseAuth.instance.currentUser?.uid != null`). Offline device-UID users are
skipped so no junk docs are created. Failures are swallowed with a debug log,
matching the existing best-effort pattern.

The write is merged so it never clobbers `displayName`, `bio`, or
`profileImagePath`.

### 2. Background sync on app launch and resume

Add `syncWorkoutProgressToFirestore()` to `SettingsService`: reads local insights
and recent sessions (trimmed to 30), and writes them to `users/{uid}` with the
same gating and best-effort error handling as step 1. No-op when there is no
Firebase session.

Call it in three places:
1. At the end of `recordWorkoutCompletion()` (step 1).
2. On app launch in `main.dart`, after auth init.
3. On app resume (background → foreground) via an `AppLifecycleListener`
   registered in `main.dart`, so a workout completed while offline gets pushed
   once connectivity returns.

### 3. Include session history in profile saves

Extend `saveInsightsToFirestore(uid, insights)` to also write `recentSessions`
(trimmed to 30) so the profile-edit sync and the post-workout sync keep the same
shape.

### 4. Restore history on Profile load

- Add `loadRecentSessionsFromFirestore(String uid)` to read the
  `recentSessions` array from `users/{uid}` into
  `List<WorkoutSessionEntry>`.
- In `first_page.dart` `_loadInsights()`, load recent sessions from Firestore
  first and fall back to local prefs when Firestore has none (new device).

### 5. Prefer the newer source on load (staleness detection)

Today `_loadInsights()` overrides local insights with Firestore data whenever it
exists, even if local is newer (e.g. an offline workout that never synced).
Compare `updatedAt`/`lastWorkoutAt` from the Firestore doc against the local
`lastWorkoutAt`: prefer whichever source is newer. When Firestore has no data,
fall back to local.

## Files

| File | Change |
| --- | --- |
| `lib/services/settings_service.dart` | Add `syncWorkoutProgressToFirestore`; call it from `recordWorkoutCompletion`; extend `saveInsightsToFirestore`; add `loadRecentSessionsFromFirestore` |
| `lib/main.dart` | Call sync on launch; register `AppLifecycleListener` for resume sync |
| `lib/pages/first_page.dart` | Load sessions from Firestore first, local fallback; prefer newer insights/session source |

## Assumptions

- Firestore security rules permit a user to read/write their own `users/{uid}`
  doc. Rules are not in the repo; the existing profile-edit sync already uses
  this path.
- **Manual checklist item:** in Firebase Console → Firestore Database → Rules,
  confirm the rules restrict `users/{uid}` to owner read/write
  (`request.auth.uid == uid`). Adding a version-controlled `firestore.rules`
  file is a separate task (must cover all collections the app uses: users,
  community, notifications, tokens).

## Testing

- `flutter analyze` clean; existing tests still pass.
- Manual: complete a workout on device A (signed in) → verify `users/{uid}`
  doc in Firestore has fresh `totalWorkouts`/`recentSessions` → on a new device
  signed in with the same account, Profile shows restored stats and history.
- Manual offline: complete a workout with no connection → reconnect / resume app
  → verify the missed workout is pushed to Firestore.
- Trim: complete 35+ workouts → verify the doc's `recentSessions` stays at 30.
