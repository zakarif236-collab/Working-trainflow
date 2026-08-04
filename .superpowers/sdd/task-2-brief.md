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
  // âœ… Enable Firestore offline persistence so cached reads resolve without a network.
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
    debugPrint('AuthService.init failed â€” proceeding with default state');
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
    // user â€” otherwise the restore can race and clobber the real account.
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
        debugPrint('[main] Offline â€” skipping anonymous sign-in, using local UID fallback');
      }
    }
  }

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Identity is settled â€” move legacy per-user prefs into the account
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
Expected: `âˆš Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 5: Manual verification checklist**

On a device/emulator:
1. Airplane mode ON. Sign in (Google). Kill the app. Reopen â†’ the app renders immediately (no black screen) and shows cached local data.
2. Re-enable network â†’ confirm the same account is still signed in (no fresh anonymous user, profile/stats intact).
3. Online cold start with a signed-in session â†’ app renders, session restored in background without clobbering.
4. Fresh device online (no session) â†’ UI visible, anonymous sign-in completes in background.
5. Verify deep links still navigate after launch (post-frame `DeepLinkService.init` unchanged).

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "fix: render first frame before auth resolution to fix offline cold start"
```
