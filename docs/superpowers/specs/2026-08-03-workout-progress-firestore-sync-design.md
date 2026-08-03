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
a best-effort Firestore write to `users/{uid}`:

```text
totalWorkouts, totalSeconds, currentStreakDays, bestStreakDays,
lastWorkoutAt, recentSessions (map), updatedAt
```

Sessions are stored as a **map keyed by `completedAt` millis**
(`recentSessions: { "<millis>": {...session} }`), not an array, so writes from
two devices merge instead of overwriting each other. One `set(..., merge: true)`
carries the stat fields plus each session under a dotted path
(`recentSessions.<millis>`); Firestore merges at the nested-key level, so
offline sessions logged on two devices both survive. A single merged document
write is atomic — no batch or transaction is needed.

The local session list is trimmed to the last 30 entries before pushing (already
bounded via `.take(30)`), capping each device's contribution; the doc may
accumulate keys across devices, and restore trims to the newest 30.

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
as a timestamp-keyed map (trimmed to 30) so the profile-edit sync and the
post-workout sync keep the same shape.

### 4. Restore history on Profile load

- Add `loadRecentSessionsFromFirestore(String uid)` to read the
  `recentSessions` map from `users/{uid}`, convert each value into a
  `WorkoutSessionEntry`, sort by key (timestamp) descending, and return the
  newest 30.
- In `first_page.dart` `_loadInsights()`, load recent sessions from Firestore
  first and fall back to local prefs when Firestore has none (new device).

### 5. Prefer the newer source on load (staleness detection)

Today `_loadInsights()` overrides local insights with Firestore data whenever it
exists, even if local is newer (e.g. an offline workout that never synced).
Compare `updatedAt`/`lastWorkoutAt` from the Firestore doc against the local
`lastWorkoutAt`: prefer whichever source is newer. When Firestore has no data,
fall back to local.

### 6. Version-controlled Firestore security rules

Add a `firestore.rules` file to the repo so rules are auditable and evolve with
code. Enumerate every collection the app reads/writes (users, community
workouts, comments, notifications, notification tokens, etc.) before writing
rules, and restrict each to the minimum access the feature needs. The
`users/{uid}` doc must be owner read/write (`request.auth.uid == uid`). Rules
are reviewed with the user before deployment; deploying is a manual step
(`firebase deploy --only firestore:rules`).

## Files

| File | Change |
| --- | --- |
| `lib/services/settings_service.dart` | Add `syncWorkoutProgressToFirestore`; call it from `recordWorkoutCompletion`; extend `saveInsightsToFirestore`; add `loadRecentSessionsFromFirestore` |
| `lib/main.dart` | Call sync on launch; register `AppLifecycleListener` for resume sync |
| `lib/pages/first_page.dart` | Load sessions from Firestore first, local fallback; prefer newer insights/session source |
| `firestore.rules` | New — version-controlled security rules (drafted, reviewed, deployed manually) |

## Assumptions

- Firestore security rules permit a user to read/write their own `users/{uid}`
  doc. The existing profile-edit sync already uses this path.
- **Manual checklist item:** after the `firestore.rules` file is drafted and
  reviewed, deploy it with `firebase deploy --only firestore:rules` and verify
  all app flows (community feed, notifications, publishing) still work.

## Testing

- `flutter analyze` clean; existing tests still pass.
- Manual: complete a workout on device A (signed in) → verify `users/{uid}`
  doc in Firestore has fresh `totalWorkouts`/`recentSessions` → on a new device
  signed in with the same account, Profile shows restored stats and history.
- Manual offline: complete a workout with no connection → reconnect / resume app
  → verify the missed workout is pushed to Firestore.
- Trim: complete 35+ workouts → verify restore keeps only the newest 30 sessions.
- Multi-device: complete workouts offline on two devices → sync both → verify
  `users/{uid}` holds sessions from both and restore shows a merged, trimmed
  history.
