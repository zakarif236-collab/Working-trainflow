# Task 2 Report: Decouple first frame from auth resolution on cold start

## Status: DONE

## What I implemented
Replaced the entire old `main()` body (previous lines 32-136) in `lib/main.dart` with the brief's Step 1 code (verbatim semantics):

- **New `main()`** (now lines 32-72): keeps `WidgetsFlutterBinding.ensureInitialized()`, `Firebase.initializeApp`, Firestore offline persistence settings, `cancelStaleNotifications`, `AuthService.init`, `ConnectivityService.initialize` as fast local init; then calls `runApp(MyApp(authService: authService))` immediately, schedules `unawaited(_finalizeStartup(authService))`, and registers the `AppLifecycleListener` and post-frame `DeepLinkService.instance.init(navigatorKey)` unchanged.
- **New `_finalizeStartup(AuthService)`** (lines 74-146): deferred network/auth work — AdMob init (Android/iOS), session-restore wait (`waitForRestoredSession()` when `hasCachedSession`), conditional `signInAnonymously().timeout(8s)` (only when online), `FirebaseMessaging.onBackgroundMessage`, `SettingsService.migrateUserData`, `NotificationService.load`, `PushNotificationService.initialize().timeout(5s)`, background `syncWorkoutProgressToFirestore()`, and the `GeminiConfig` assert.

`_firebaseMessagingBackgroundHandler` (27-30), `MyApp` (148-180), `navigatorKey`, and all imports are untouched. `dart:async` already provides `unawaited`.

Note on "verbatim": the brief's markdown file contains mojibake for the em-dash/checkmark characters (`â€”`, `âœ…`) — an encoding artifact. I reproduced the intended Unicode (em dash `—`, checkmark `✅`) to match the existing file's style. Code semantics are identical either way.

## Verification results

### `flutter analyze`
- Ran once, 29.0s.
- **11 issues, all pre-existing infos, NONE in `lib/main.dart`:**
  - `avoid_print`: community_page.dart:105,112; home_page.dart:59; workout_builder_page.dart:104; community_firestore_service.dart:26,65,67,70
  - `avoid_types_as_parameter_names`: community_firestore_service.dart:334,335,336
- **No new issues introduced by this change.**

### `flutter test`
- Ran once. **40 tests: 37 passed, 3 failed.**
- The 3 failures are exactly the documented pre-existing baseline (timer-pending, `A Timer is still pending` for the 8s Firestore insights timer in `_FirstPageState`):
  1. `widget_test.dart: Workout timer is shown by default on home tab`
  2. `widget_test.dart: VO2max quick start opens workout page`
  3. `widget_test.dart: Calisthenics quick start opens workout page`
- **No other failures; no new failures. Tests pump `MyApp` directly and never call `main()`, so the restructure did not affect them** (failure stack traces reference `first_page.dart`/`settings_service.dart` timers, unchanged by this task).

### `flutter build apk --debug`
- Ran once (37.8s Gradle).
- Final line: `√ Built build\app\outputs\flutter-apk\app-debug.apk`
- One pre-existing plugin warning (KGP for flutter_timezone, package_info_plus, share_plus, wakelock_plus) — unrelated to this change.

## Files changed
- Only `lib/main.dart` (27 insertions, 17 deletions).
- The working tree's uncommitted changes in `lib/firebase_options.dart` and `lib/widgets/workout_schedule_section.dart` were NOT modified, staged, or reverted.

## Commit
- `e183748` fix: render first frame before auth resolution to fix offline cold start (staged ONLY `lib/main.dart`)

## Self-review findings
- Completeness: old `main()` body fully replaced; no leftover duplicates. `runApp` is reachable on every path (no early returns/throws before it; all deferred work is wrapped in try/catch inside `_finalizeStartup`). `_finalizeStartup` is unawaited from `main`. Handler, `MyApp`, imports untouched.
- Ordering/timeouts: `waitForRestoredSession()` (un-timed, per brief), `signInAnonymously().timeout(Duration(seconds: 8))`, `PushNotificationService.initialize().timeout(Duration(seconds: 5))` all preserved exactly, just deferred.
- Discipline: only `lib/main.dart` touched; no comments added beyond the brief's code.
- Minor decision (documented above): rendered brief comments with proper Unicode instead of the brief file's mojibake.

## Issues / concerns
- None blocking. Manual verification (brief Step 5, on-device) still needs to be performed by a human; automated checks all pass.
