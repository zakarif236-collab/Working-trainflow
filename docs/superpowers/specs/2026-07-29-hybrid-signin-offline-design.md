# Hybrid Sign-In + Offline Mode

**Date:** 2026-07-29
**Status:** Approved
**Approach:** 1 — Anonymous Auth + Gated Tabs

## Problem

The sign-in requirement blocks offline use of Mods. The app relies on the user's Firestore uid for saved workouts, so when offline, auth fails and the section breaks. However, sign-in is also needed for Community and syncing.

## Solution Overview

Split responsibilities: anonymous auth guarantees a uid even offline, tab gates are relaxed for offline-capable sections, and account linking upgrades anonymous users to permanent accounts without data loss.

## Architecture

### 1. AuthService — Anonymous Auth & Account Linking

**New methods:**
- `signInAnonymously()` — calls `FirebaseAuth.instance.signInAnonymously()`
- `bool get isAnonymous` — `_auth.currentUser?.isAnonymous ?? false`
- `linkWithGoogle()` — links Google credential to current anonymous user via `currentUser!.linkWithCredential(GoogleAuthProvider.credential(...))`
- `linkWithEmail(email, password)` — links email/password via `currentUser!.linkWithCredential(EmailAuthProvider.credential(email, password))`

**Startup flow in `main()`:**
After `Firebase.initializeApp()`, call `AuthService().signInAnonymously()` (try-catch). This guarantees a non-null `uid` at all times.

**Sign-in flow in `AuthSheet`:**
- If `_authService.isAnonymous` → call `linkWithGoogle()` / `linkWithEmail()` (which link the credential to the anonymous account)
- Else → call existing `signInWithGoogle()` / `signIn()` (fresh sign-in for signed-out or already-permanent users)

**Sign-out:** Unchanged — signs out the current (now linked) account.

### 2. MainShellPage — Tab Auth Gates

Remove auth gate for tabs 1 (Mods) and 2 (Activity). Only tab 3 (Profile) gates behind sign-in:

```dart
Future<void> _onTabSelected(int index) async {
  if (index == 3) { // Profile
    if (_authService.currentUserId == null) {
      final signedIn = await AuthPage.showAsSheet(context);
      if (signedIn != true || !mounted) return;
      OnboardingSheet.showIfNeeded(context, _authService);
    }
  }
  setState(() { ... });
}
```

### 3. HomePage (Mods) — Community Card Offline State

Community card stays visible but is non-tappable when offline:
- `onTap` set to `null` when `!ConnectivityService.instance.isOnline`
- Subtitle changes to "Sign in when online"
- Card dims visually to indicate disabled state

### 4. CommunityPage — No Structural Changes

- `_requireAuth()` already shows auth sheet — sheet now handles anonymous linking automatically
- `CommunityFirestoreService` already guards with `if (_uid == null) return;` — with anonymous auth, these guards always pass
- `OfflineBanner` already displays connectivity state
- SyncQueue already replays on reconnect via `ConnectivityService._onReconnect()`

### 5. SyncQueue + Account Linking — Conflict Resolution

After successful anonymous → permanent link:

1. **Saved workout deduplication** — Scan local `WorkoutBuilderRoutine` list for routines with identical name + exercise fingerprint. Keep the newest, remove older duplicates.
2. **Like/save state reset** — `_applyUserState` checks the new `_uid`. States from anonymous uid won't carry over. Reload Community data on reconnect to refresh.
3. **Orphaned anonymous Firestore cleanup** — Best-effort delete of anonymous uid's subcollections (`savedWorkouts`, `liked_workouts`, `rated_workouts`, `following`). Wrapped in try-catch.
4. **SyncQueue drain** — Clear queued actions on successful link since they reference the anonymous uid and cannot be replayed.

### 6. Data Flow Summary

| Scenario | Auth State | Mods (Builder/QuickStart) | Community | Profile | Activity |
|----------|-----------|--------------------------|-----------|---------|----------|
| Fresh install, online | Anonymous | Works | Works (save/like uses anonymous uid) | Prompts sign-in | Works |
| Fresh install, offline | Anonymous | Works (local data) | Works (local cache), actions queued | Prompts sign-in | Works |
| Signed in, online | Permanent uid | Works | Works (real uid) | Works | Works |
| After sign-in, offline | Permanent uid | Works (local data) | Works (local cache), actions queued | Works (cached) | Works |
| Anonymous → sign in | Links to permanent | Dedup local routines | Reloads with new uid | Works | Works |

## Files Changed

- `lib/services/auth_service.dart` — Add anonymous sign-in, linking methods, `isAnonymous`
- `lib/pages/main_shell_page.dart` — Relax tab gate for indexes 1, 2
- `lib/pages/home_page.dart` — Disable Community card when offline
- `lib/pages/auth_page.dart` — Detect anonymous state and use linking
- `lib/main.dart` — Call `signInAnonymously()` on startup
- `lib/services/sync_queue.dart` — Add `clear()` method for post-link drain
- `lib/models/workout_models.dart` — Add `WorkoutBuilderRoutine.fingerprint` getter for dedup
- `lib/services/settings_service.dart` — Add dedup helper method

## Not Changed

- `CommunityFirestoreService` — Already handles null uid gracefully
- `ConnectivityService` — Already triggers `SyncQueue.processQueue()` on reconnect
- `OfflineBanner` — Already displays offline state correctly
- `workout_builder_page.dart` — Already works with local SharedPreferences
