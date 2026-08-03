# Multi-Device Sync Convergence

Date: 2026-08-03

## Problem

The workout-progress sync writes `users/{uid}` with per-key merge, so offline
sessions from multiple devices already survive in Firestore. But the app never
merges the remote union back into local SharedPreferences: a device that reads
the union and then goes offline loses sight of the other device's sessions. The
cumulative scalars (`totalWorkouts`, `totalSeconds`, `currentStreakDays`,
`bestStreakDays`, `lastWorkoutAt`) are also resolved with last-write-wins, so a
device with a stale counter can clobber a shared total.

## Goal

Make all devices converge to the same workout history and stats: merge remote
sessions into local storage on read, and resolve cumulative scalars from the
merged session set so no device can regress another's totals.

## Current State

- Sessions sync as a timestamp-keyed map (`sessionsToFirestoreMap`) with
  `set(..., merge: true)` under dotted paths — per-key conflict-safe already.
- `first_page.dart` `_loadInsights()` reads remote sessions and displays them,
  but never persists them locally.
- Scalar fields are overwritten by whichever device syncs last (last-write-wins).
- Session storage cap is 30, hardcoded in four places (record, sync, restore,
  map build).
- `firestore.rules` is git-tracked, but `firebase.json` has no `firestore`
  section, so `firebase deploy` will not push rules. The delete rule hardcodes an
  admin email.

## Design

### 1. Session merge-on-read (union)

Add `SettingsService.mergeRemoteInsights(String uid)`:

1. Load local insights and local sessions (capped at `_kSessionStorageCap`).
2. Load remote insights and remote sessions (existing methods, 8s timeout).
3. `mergeSessionsByTimestamp(local, remote)`: union by the
   `completedAt.millisecondsSinceEpoch` key, dedup, sort descending, cap at
   `_kSessionStorageCap`.
4. Resolve scalars from the union (Section 2) and persist union + scalars to
   local prefs (no Firestore write here — the next natural
   `syncWorkoutProgressToFirestore()` push propagates the union).
5. Return the merged `WorkoutInsights` and session list.

`first_page.dart` `_loadInsights()` online branch collapses to one call to
`mergeRemoteInsights(uid)`. The Profile display uses the union (not "remote if
non-empty"), and the result is persisted so the device converges even after
going offline again.

### 2. Conflict-safe scalars

- New pure helper `computeStreaks(List<WorkoutSessionEntry>)` returning
  `(current, best)` from unique consecutive session days. Deterministic and
  testable.
- Resolved insights:
  - `displayName`, `bio`, `profileImagePath`: from the newer-lastWorkout rule
    (existing `pickNewerInsights` semantics).
  - `totalWorkouts`: count of union sessions.
  - `totalSeconds`: sum of union session durations.
  - `lastWorkoutAt`: latest session time (null when the union is empty).
  - `currentStreakDays`, `bestStreakDays`: from `computeStreaks`.
- **Truncation guard:** when the union reaches `_kSessionStorageCap` (list is
  incomplete), fall back to monotonic `max(local, remote)` for all counters and
  the later `lastWorkoutAt`, so a heavy user's stored totals never drop (e.g.
  150 → 100).

### 3. Shared session cap constant

Define `_kSessionStorageCap = 100` and use it in all five sites:
`recordWorkoutCompletion` (L1035), `sessionsToFirestoreMap` (L1176),
`loadRecentSessionsFromFirestore` (L913), the sync `loadRecentSessions(limit:)`
call (L953), and the new merge method. The UI display cap (7) is unchanged.

**Performance note:** at cap 100 the union sort and streak recompute are
negligible. If the cap is ever raised significantly, revisit incremental streak
maintenance — out of scope now.

### 4. Rules deployment + admin parameterization

- `firebase.json`: add `"firestore": { "rules": "firestore.rules" }` so
  `firebase deploy` pushes the rules file.
- Replace the hardcoded admin email in the `community_workouts` delete rule with
  a custom claim check: `request.auth.token.admin == true`. Grant the claim
  once via the Firebase Admin SDK:
  `setCustomUserClaims(uid, {admin: true})`. No email in rules, no extra
  collection. Document this step in the plan's manual checklist.

## Files

| File | Change |
| --- | --- |
| `lib/services/settings_service.dart` | Add `_kSessionStorageCap`; add `mergeRemoteInsights`, `mergeSessionsByTimestamp`, `computeStreaks`, scalar resolution + truncation guard; replace hardcoded `take(30)` sites with the cap |
| `lib/pages/first_page.dart` | Online branch calls `mergeRemoteInsights(uid)`; display and persist the union |
| `firebase.json` | Add `firestore.rules` reference |
| `firestore.rules` | Replace admin email check with `request.auth.token.admin == true` |
| `test/workout_progress_sync_test.dart` | New unit tests (below) |

## Assumptions

- The admin already has the `admin: true` custom claim set via the Admin SDK
  before the updated rules are deployed.
- **Manual checklist item:** deploy rules with
  `firebase deploy --only firestore:rules` and verify community delete
  permissions still behave.

## Testing

- `mergeSessionsByTimestamp`: union, dedup, cap, ordering.
- `computeStreaks`: consecutive days, a gap (streak resets), single session,
  empty list.
- Scalar merge: complete-list recompute vs truncated-list monotonic fallback.
- Cap-100 `buildWorkoutSyncData` no longer trims below the cap.
- **Two-device converge:** simulate device A's local sessions and device B's
  disjoint offline sessions; run merge for A → union contains both sets;
  recomputed totals = sum; repeat for B → identical converged state.
