# Offline Cold-Start First-Frame Decoupling — Design Spec

## Goal
Eliminate the black screen on offline cold start when signed in: first frame must render cached local data immediately, without waiting for FirebaseAuth session restore or any network-touching initialization.

## Root Cause
`main()` awaits a blocking chain before calling `runApp()` (`lib/main.dart:55-129`). The dominant blocker is `AuthService.waitForRestoredSession()`, which awaits `authStateChanges()` for up to 8 seconds (`lib/services/auth_service.dart:90-109`). Offline, a signed-in Google session's restore does not emit quickly, so the full timeout elapses. `PushNotificationService.initialize()` then adds up to 5 seconds more. During that window the Flutter engine is up but no frame has been drawn; in dark mode the `NormalTheme` window background is black (`android/app/src/main/res/values-night/styles.xml:15-16`), producing the black screen.

`FirstPage` is not the culprit — it loads local data immediately and gates Firestore merges on `isOnline` (`lib/pages/first_page.dart:47-68`).

## Architecture
Move only the fast, local, first-frame dependencies before `runApp`. Defer all network-touching and auth-resolution work to a non-blocking post-frame step. Preserve the anti-clobber ordering (wait for session restore before anonymous sign-in) but run it off the critical path.

## Components

| Component | File | Purpose |
|-----------|------|---------|
| `main()` | `lib/main.dart` | Fast init, then `runApp` immediately |
| `_finalizeStartup()` | `lib/main.dart` | Deferred: auth restore, anonymous sign-in, push init, migration, sync |

## Change

### Before `runApp` (fast, local-only)
1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp(...)`
3. Firestore `persistenceEnabled: true` settings
4. `authService.init()` — loads cached UID from SharedPreferences; pages depend on `resolvedUserId` at first frame
5. `ConnectivityService.instance.initialize()` — `isOnline` is local; pages gate on it
6. Notification cleanup (`cancelStaleNotifications`)
7. `runApp(MyApp(authService: authService))`
8. `unawaited(_finalizeStartup(authService))`

### After first frame — `_finalizeStartup(authService)`
1. Session-restore wait: if `!hasFirebaseSession && hasCachedSession`, `await waitForRestoredSession()` (same 8s budget)
2. Conditional anonymous sign-in: if still `!hasFirebaseSession` and online, `signInAnonymously().timeout(8s)`; if offline, skip (local UID fallback)
3. `SettingsService.migrateUserData()`
4. `NotificationService.instance.load()`
5. `PushNotificationService.instance.initialize().timeout(5s)`
6. Unawaited background sync (`syncWorkoutProgressToFirestore`)
7. `FirebaseMessaging.onBackgroundMessage` registration

### Moved to deferred path
- `MobileAds.instance.initialize()` — no first-frame dependency; keeps try/catch
- `FirebaseMessaging.onBackgroundMessage` registration
- `SettingsService.migrateUserData()`, `PushNotificationService.initialize()`, `NotificationService.load()`
- Background sync already `unawaited`; stays in deferred path

### Kept after `runApp` (unchanged behavior)
- `AppLifecycleListener(onResume: sync)`
- `DeepLinkService.instance.init(navigatorKey)` post-frame callback

## Data Flow
1. Process starts → LaunchTheme splash.
2. Fast local init completes → `runApp` → first frame renders `MainShellPage` with cached local data.
3. `_finalizeStartup` runs in background: waits for session restore (up to 8s), then conditionally signs in anonymously without racing the restore.
4. Identity settles → `migrateUserData` runs under the resolved namespace → push init and background sync proceed.

## Edge Cases
- Offline cold start, signed in: UI appears immediately with local data; restore times out silently in background; no anonymous sign-in offline.
- Online cold start, signed in: restore resolves in background; no clobbering.
- Fresh device online: no cached session → anonymous sign-in proceeds in background; UI already visible.
- Identity changes after first frame (anonymous vs. restored): pages read `resolvedUserId`/`hasFirebaseSession` live; `FirstPage` reloads on refresh. Acceptable — same identity the pre-fix code settled before first frame, just resolved a moment later.
- `OnboardingSheet`/Profile-tab sign-in gate read `hasFirebaseSession` at tap time — unaffected.

## Testing
- Run `flutter test`.
- Build debug APK.
- Manual: airplane mode + signed in + kill + reopen → UI renders immediately with local data. Re-enable network → confirm account is not clobbered by anonymous sign-in (same UID still signed in).
