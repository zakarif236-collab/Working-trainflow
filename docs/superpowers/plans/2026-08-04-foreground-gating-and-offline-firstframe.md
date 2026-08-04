# Foreground Notification Gating + Offline Cold-Start First-Frame Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** (1) Stop the workout companion notification from appearing while the app is in the foreground, and (2) eliminate the offline cold-start black screen by calling `runApp` before auth resolution.

**Architecture:** Two independent fixes. The notification fix adds an `_isForegrounded` flag to `WorkoutForegroundService` that gates the companion notification on the promote/demote lifecycle already in place. The startup fix splits `main()` into a fast local-init section followed by immediate `runApp`, deferring all network/auth work to an unawaited `_finalizeStartup()`.

**Tech Stack:** Dart, Flutter, `flutter_background_service` 5.1.0, `flutter_local_notifications` 19.4.0, Firebase (Auth / Firestore / Messaging), Google Mobile Ads.

## Global Constraints

- Per approved spec `docs/superpowers/specs/2026-08-04-foreground-notification-gating-design.md`: no unit test for the gating change — the service is coupled to platform channels; verify via `flutter analyze`, `flutter build apk --debug`, and the manual checklist in Task 1.
- Per approved spec `docs/superpowers/specs/2026-08-04-offline-coldstart-first-frame-design.md`: the session-restore wait and anonymous sign-in must keep their exact ordering and timeouts (8s each), just moved off the critical path.
- No other files than those listed in each task may be modified.
- `runApp` must still be reached on every startup path; `_finalizeStartup` must never throw an uncaught error that could crash after first frame (all its bodies are already wrapped in try/catch or have timeouts).
- Commit after each task.

---

### Task 1: Gate companion notification on foreground state

**Files:**
- Modify: `lib/services/workout_foreground_service.dart` (fields ~31-32, `start` ~72-74, `promoteToForeground` ~114-122, `demoteToBackground` ~125-131, `stop` ~134-144, `update` ~162-167)

**Interfaces:**
- Consumes: existing public API (`start`, `promoteToForeground`, `demoteToBackground`, `update`, `stop`) — signatures unchanged.
- Produces: internal `bool _isForegrounded` that is true only while the companion notification is visible.

- [ ] **Step 1: Add the `_isForegrounded` field**

Locate the fields block (~lines 31-34):

```dart
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  bool _actionForwarderAttached = false;
```

Replace it with:

```dart
  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// True only while the companion notification is visible (i.e. the app is
  /// backgrounded/locked). Guards `_showActionNotification` in [update] so no
  /// notification is posted while the user is inside the app.
  bool _isForegrounded = false;

  bool _actionForwarderAttached = false;
```

- [ ] **Step 2: Reset the flag in `start`**

In `start()` (~lines 67-74), find:

```dart
    _isPaused = false;
    _isMusicPlaying = isMusicPlaying;
    _lastActionContent = '';
```

Replace with:

```dart
    _isPaused = false;
    _isMusicPlaying = isMusicPlaying;
    _isForegrounded = false;
    _lastActionContent = '';
```

- [ ] **Step 3: Set the flag in `promoteToForeground`**

Find:

```dart
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
```

Replace with:

```dart
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _isForegrounded = true;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
```

- [ ] **Step 4: Clear the flag in `demoteToBackground`**

Find:

```dart
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _service.invoke('setAsBackground');
```

Replace with:

```dart
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _isForegrounded = false;
    _service.invoke('setAsBackground');
```

- [ ] **Step 5: Clear the flag in `stop`**

Find:

```dart
    _service.invoke('stop');
    _isRunning = false;

    if (Platform.isAndroid) {
```

Replace with:

```dart
    _service.invoke('stop');
    _isRunning = false;
    _isForegrounded = false;

    if (Platform.isAndroid) {
```

- [ ] **Step 6: Gate the companion notification in `update`**

Find:

```dart
    if (_isRunning) {
      _updateForegroundNotificationInfo();
      if (Platform.isAndroid) {
        await _showActionNotification();
      }
    }
```

Replace with:

```dart
    if (_isRunning) {
      _updateForegroundNotificationInfo();
      if (Platform.isAndroid && _isForegrounded) {
        await _showActionNotification();
      }
    }
```

- [ ] **Step 7: Analyze**

Run: `flutter analyze`
Expected: no new issues in `lib/services/workout_foreground_service.dart` (pre-existing project warnings may remain).

- [ ] **Step 8: Build debug APK**

Run: `flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 9: Manual verification checklist**

On a device/emulator:
1. Start a workout, stay in the app ≥ 5s → no notification appears in the shade.
2. Press Home (background) → companion Pause/Stop notification appears.
3. Lock the phone → notification still visible on the lock screen.
4. Unlock and reopen app → notification disappears.
5. Stop/reset the workout, start a new one → no stale notification, and while in-app again no notification.
6. While backgrounded, verify Pause/Stop buttons still work from the notification.

- [ ] **Step 10: Commit**

```bash
git add lib/services/workout_foreground_service.dart
git commit -m "fix: gate workout companion notification on foreground state"
```

---

### Task 2: Decouple first frame from auth resolution on cold start

**Files:**
- Modify: `lib/main.dart` (`main` ~32-136)

**Interfaces:**
- Consumes: existing `AuthService`, `ConnectivityService`, `SettingsService.migrateUserData`, `NotificationService.instance.load`, `PushNotificationService.instance.initialize`, `WorkoutForegroundService.cancelStaleNotifications`, `MobileAds.instance.initialize`, `DeepLinkService.instance.init`, `_firebaseMessagingBackgroundHandler`.
- Produces: `Future<void> _finalizeStartup(AuthService authService)` top-level function in `lib/main.dart`. No other file depends on it.

- [ ] **Step 1: Rewrite `main` and add `_finalizeStartup`**

Replace the entire `main()` body (lines 32-136, from `Future<void> main() async {` through the closing brace at line 136) with:

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // ✅ Enable Firestore offline persistence so cached reads resolve without a network.
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      FirebaseFirestore.instance.settings =
          const Settings(persistenceEnabled: true);
    } catch (_) {}
  }

  try {
    await WorkoutForegroundService.cancelStaleNotifications();
  } catch (_) {}

  final authService = AuthService();
  try {
    await authService.init();
  } catch (_) {
    debugPrint('AuthService.init failed — proceeding with default state');
  }

  try {
    await ConnectivityService.instance.initialize();
  } catch (e) {
    debugPrint('[main] Connectivity init failed: $e');
  }

  // Render the first frame from cached local data immediately. Everything that
  // touches the network or waits on FirebaseAuth runs deferred in
  // _finalizeStartup so an offline cold start never shows a blank window.
  runApp(MyApp(authService: authService));
  unawaited(_finalizeStartup(authService));

  AppLifecycleListener(
    onResume: () => SettingsService().syncWorkoutProgressToFirestore(),
  );
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DeepLinkService.instance.init(navigatorKey);
  });
}

/// Deferred startup work that must not block the first frame: session restore
/// wait (anti-clobber), conditional anonymous sign-in, AdMob, push
/// notifications, key migration, and background sync.
Future<void> _finalizeStartup(AuthService authService) async {
  if (Platform.isAndroid || Platform.isIOS) {
    try {
      await MobileAds.instance.initialize();
    } catch (e) {
      debugPrint('[main] AdMob init failed: $e');
    }
  }

  if (!authService.hasFirebaseSession) {
    // Cold start: FirebaseAuth may still be restoring a cached session, so a
    // null currentUser here does not mean this device has no account. Give any
    // persisted session a chance to restore before creating a fresh anonymous
    // user — otherwise the restore can race and clobber the real account.
    if (authService.hasCachedSession) {
      try {
        await authService.waitForRestoredSession();
      } catch (_) {
        debugPrint('[main] Failed waiting for session restore');
      }
    }

    if (!authService.hasFirebaseSession) {
      if (ConnectivityService.instance.isOnline) {
        try {
          await authService
              .signInAnonymously()
              .timeout(const Duration(seconds: 8));
        } catch (_) {
          debugPrint('[main] Firebase Auth unavailable, using local UID fallback');
        }
      } else {
        debugPrint('[main] Offline — skipping anonymous sign-in, using local UID fallback');
      }
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Identity is settled — move legacy per-user prefs into the account
  // namespace so local stats don't mix across accounts on this device.
  try {
    await SettingsService.migrateUserData();
  } catch (_) {
    debugPrint('[main] User-data key migration skipped');
  }

  try {
    await NotificationService.instance.load();
  } catch (_) {
    debugPrint('[main] NotificationService.load failed');
  }
  try {
    await PushNotificationService.instance.initialize().timeout(const Duration(seconds: 5));
  } catch (_) {
    debugPrint('[main] PushNotification init skipped (offline or timeout)');
  }

  // Best-effort background sync; never block anything on the network.
  unawaited(SettingsService().syncWorkoutProgressToFirestore());

  assert(() {
    if (GeminiConfig.isConfigured) {
      debugPrint('Gemini voice-over key is configured.');
    } else {
      debugPrint('Gemini voice-over key is missing.');
    }
    return true;
  }());
}
```

Keep the `_firebaseMessagingBackgroundHandler` function (lines 27-30), the `MyApp` class, and all imports unchanged. The `dart:async` import already provides `unawaited`.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: no new issues in `lib/main.dart`.

- [ ] **Step 3: Run existing tests**

Run: `flutter test`
Expected: all existing tests pass (tests pump `MyApp` directly and never call `main()`, so the restructure does not affect them).

- [ ] **Step 4: Build debug APK**

Run: `flutter build apk --debug`
Expected: `√ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 5: Manual verification checklist**

On a device/emulator:
1. Airplane mode ON. Sign in (Google). Kill the app. Reopen → the app renders immediately (no black screen) and shows cached local data.
2. Re-enable network → confirm the same account is still signed in (no fresh anonymous user, profile/stats intact).
3. Online cold start with a signed-in session → app renders, session restored in background without clobbering.
4. Fresh device online (no session) → UI visible, anonymous sign-in completes in background.
5. Verify deep links still navigate after launch (post-frame `DeepLinkService.init` unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "fix: render first frame before auth resolution to fix offline cold start"
```
