# Hybrid Sign-In + Offline Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the app fully usable offline — Default Timer and Mods work without sign-in — while keeping Community and Profile behind auth.

**Architecture:** Firebase Anonymous Auth guarantees a uid at all times. Tab gates in MainShellPage are relaxed for offline-capable sections (Mods, Activity). The AuthSheet detects anonymous state and links credentials instead of creating new accounts. Conflict resolution handles deduplication and cleanup on anonymous → permanent upgrade.

**Tech Stack:** Flutter, Firebase Auth, Firebase Anonymous Auth, SharedPreferences, ConnectivityService, SyncQueue

## Global Constraints

- Anonymous Auth must be enabled in Firebase Console
- No new dependencies beyond firebase_auth (already present)
- No restructuring of existing large files
- Local SharedPreferences is the source of truth for workout data
- Anonymous Firestore data is ephemeral — no migration

---

### Task 1: AuthService — Anonymous Auth and Linking

**Files:**
- Modify: `lib/services/auth_service.dart`

**Interfaces:**
- Consumes: None (independent)
- Produces: `signInAnonymously()`, `linkWithGoogle()`, `linkWithEmail(String, String)`, `get isAnonymous`

- [ ] **Step 1: Add anonymous sign-in method**

```dart
Future<void> signInAnonymously() async {
  await _auth.signInAnonymously();
}
```

- [ ] **Step 2: Add `isAnonymous` getter**

```dart
bool get isAnonymous => _auth.currentUser?.isAnonymous ?? false;
```

- [ ] **Step 3: Add linking methods**

```dart
Future<void> linkWithGoogle() async {
  final googleUser = await _google.signIn();
  if (googleUser == null) throw const AuthServiceException('Google sign-in was cancelled.');
  final googleAuth = await googleUser.authentication;
  if (googleAuth.idToken == null) {
    throw const AuthServiceException(
      'Failed to get Google ID token. Make sure the OAuth consent screen is Published.',
    );
  }
  final credential = GoogleAuthProvider.credential(
    accessToken: googleAuth.accessToken,
    idToken: googleAuth.idToken,
  );
  await _auth.currentUser!.linkWithCredential(credential);
}

Future<void> linkWithEmail(String email, String password) async {
  final credential = EmailAuthProvider.credential(email: email.trim(), password: password);
  await _auth.currentUser!.linkWithCredential(credential);
}
```

- [ ] **Step 4: Verify the file compiles**

Run: `cd lib && dart analyze services/auth_service.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: add anonymous auth and credential linking to AuthService"
```

---

### Task 2: Startup — Wire Anonymous Sign-In in main.dart

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AuthService.signInAnonymously()`
- Produces: Anonymous user active before `runApp()`

- [ ] **Step 1: Add anonymous sign-in call after Firebase init**

Insert after `await Firebase.initializeApp(...)` and before the messaging setup:

```dart
try {
  await AuthService().signInAnonymously();
} catch (_) {
  // Anonymous sign-in is best-effort; the app works without it,
  // but some Firestore features will be unavailable until real sign-in.
}
```

Import `AuthService` at the top of the file (already imported).

- [ ] **Step 2: Verify the file compiles**

Run: `cd lib && dart analyze main.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: auto sign-in anonymously on startup"
```

---

### Task 3: AuthSheet — Handle Anonymous Linking

**Files:**
- Modify: `lib/pages/auth_page.dart`

**Interfaces:**
- Consumes: `AuthService.isAnonymous`, `AuthService.linkWithGoogle()`, `AuthService.linkWithEmail()`
- Produces: Auth sheet that links credentials when current user is anonymous

- [ ] **Step 1: Replace `_signInWithGoogle` to use linking when anonymous**

```dart
Future<void> _signInWithGoogle() async {
  setState(() => _isGoogleLoading = true);
  try {
    if (widget.authService.isAnonymous) {
      await widget.authService.linkWithGoogle();
    } else {
      await widget.authService.signInWithGoogle();
    }
    if (mounted) Navigator.of(context).pop(true);
  } on AuthServiceException catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e.message), behavior: SnackBarBehavior.floating),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Google sign-in failed: $e'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } finally {
    if (mounted) setState(() => _isGoogleLoading = false);
  }
}
```

- [ ] **Step 2: Replace `_submit` to use linking when anonymous**

```dart
Future<void> _submit() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;
  setState(() => _isLoading = true);
  try {
    if (widget.authService.isAnonymous) {
      await widget.authService.linkWithEmail(
        _emailController.text,
        _passwordController.text,
      );
      if (_isSignUp) {
        await _auth.currentUser?.updateDisplayName(_displayNameController.text);
      }
    } else {
      if (_isSignUp) {
        await widget.authService.signUp(
          _emailController.text,
          _passwordController.text,
          _displayNameController.text,
        );
      } else {
        await widget.authService.signIn(
          _emailController.text,
          _passwordController.text,
        );
      }
    }
    if (mounted) Navigator.of(context).pop(true);
  } on FirebaseAuthException catch (e) {
    if (!mounted) return;
    final message = _mapError(e.code);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  } catch (_) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Something went wrong. Please try again.'), behavior: SnackBarBehavior.floating),
    );
  } finally {
    if (mounted) setState(() => _isLoading = false);
  }
}
```

Import `EmailAuthProvider` at top: `import 'package:firebase_auth/firebase_auth.dart';` (already imported).

- [ ] **Step 3: Verify the file compiles**

Run: `cd lib && dart analyze pages/auth_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/pages/auth_page.dart
git commit -m "feat: link credentials when anonymous in AuthSheet"
```

---

### Task 4: MainShellPage — Relax Tab Auth Gates

**Files:**
- Modify: `lib/pages/main_shell_page.dart`

**Interfaces:**
- Consumes: `AuthService.currentUserId`
- Produces: Tabs 0, 1, 2 freely accessible; tab 3 (Profile) gated behind sign-in

- [ ] **Step 1: Change `_onTabSelected` to only gate tab 3**

Replace the current `_onTabSelected`:

```dart
Future<void> _onTabSelected(int index) async {
  if (index == 3) {
    if (_authService.currentUserId == null) {
      final signedIn = await AuthPage.showAsSheet(context);
      if (signedIn != true || !mounted) return;
      OnboardingSheet.showIfNeeded(context, _authService);
    }
  }
  setState(() {
    if (index == 0) {
      _homeTimerKey++;
      _pendingWorkoutConfig = null;
    }
    _selectedIndex = index;
  });
}
```

- [ ] **Step 2: Verify the file compiles**

Run: `cd lib && dart analyze pages/main_shell_page.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/pages/main_shell_page.dart
git commit -m "feat: only gate Profile tab behind sign-in"
```

---

### Task 5: HomePage — Disable Community Card When Offline

**Files:**
- Modify: `lib/pages/home_page.dart`

**Interfaces:**
- Consumes: `ConnectivityService.instance.isOnline`
- Produces: Community card visually disabled when offline

- [ ] **Step 1: Import ConnectivityService**

Add at top (if not already present):
```dart
import 'package:my_app/services/connectivity_service.dart';
```

- [ ] **Step 2: Modify the Community card `_ModCard`**

Replace the existing Community card's `onTap` and subtitle:

```dart
_ModCard(
  title: 'Community',
  subtitle: ConnectivityService.instance.isOnline
      ? 'Share & discover'
      : 'Sign in when online',
  icon: Icons.public_rounded,
  gradient: const [Color(0xFFF97316), Color(0xFFF5A97D)],
  onTap: ConnectivityService.instance.isOnline
      ? () => _openCommunity(context)
      : null,
),
```

- [ ] **Step 3: Verify the file compiles**

Run: `cd lib && dart analyze pages/home_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/pages/home_page.dart
git commit -m "feat: disable Community card when offline"
```

---

### Task 6: Model + SyncQueue + SettingsService — Utility Changes

**Files:**
- Modify: `lib/models/workout_models.dart`
- Modify: `lib/services/sync_queue.dart`
- Modify: `lib/services/settings_service.dart`

**Interfaces:**
- Consumes: None (utility methods)
- Produces: `WorkoutBuilderRoutine.fingerprint`, `SyncQueue.clear()`, `SettingsService.deduplicateWorkoutRoutines()`

- [ ] **Step 1: Add `fingerprint` getter to `WorkoutBuilderRoutine`**

In `lib/models/workout_models.dart`, add to `WorkoutBuilderRoutine`:

```dart
String get fingerprint {
  final buffer = StringBuffer(name.trim().toLowerCase());
  for (final exercise in exercises) {
    buffer.write('|${exercise.name.trim().toLowerCase()}');
    buffer.write(':${exercise.workSeconds}:${exercise.restSeconds}');
  }
  return buffer.toString();
}
```

Place it after `estimatedDurationSeconds` and before `copyWith`.

- [ ] **Step 2: Add `clear()` to `SyncQueue`**

In `lib/services/sync_queue.dart`, add:

```dart
Future<void> clear() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_queueKey);
}
```

Place it after `processQueue` and before `_execute`.

- [ ] **Step 3: Add `deduplicateWorkoutRoutines()` to `SettingsService`**

In `lib/services/settings_service.dart`, add:

```dart
Future<void> deduplicateWorkoutRoutines() async {
  final routines = await loadWorkoutBuilderRoutines();
  if (routines.length < 2) return;
  final seen = <String>{};
  final deduped = <WorkoutBuilderRoutine>[];
  for (final routine in routines) {
    if (seen.add(routine.fingerprint)) {
      deduped.add(routine);
    }
  }
  if (deduped.length == routines.length) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(
    _kWorkoutBuilderRoutines,
    jsonEncode(deduped.map((e) => e.toJson()).toList()),
  );
}
```

- [ ] **Step 4: Verify all three files compile**

Run: `cd lib && dart analyze models/workout_models.dart services/sync_queue.dart services/settings_service.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/models/workout_models.dart lib/services/sync_queue.dart lib/services/settings_service.dart
git commit -m "feat: add fingerprint, clear(), and dedup helpers"
```

---

### Task 7: Wire Linking Conflict Resolution

**Files:**
- Modify: `lib/pages/auth_page.dart`

**Interfaces:**
- Consumes: `SyncQueue.clear()`, `SettingsService.deduplicateWorkoutRoutines()`
- Produces: Post-link cleanup — dedup routines, clear sync queue, reload page

- [ ] **Step 1: Add cleanup after successful link in `_signInWithGoogle`**

Within the `try` block after `linkWithGoogle()` succeeds, add:

```dart
// Clean up after anonymous → permanent link
import 'package:my_app/services/sync_queue.dart';
import 'package:my_app/services/settings_service.dart';

// ... after await widget.authService.linkWithGoogle():
final settings = SettingsService();
await settings.deduplicateWorkoutRoutines();
await SyncQueue.instance.clear();
```

- [ ] **Step 2: Add same cleanup after successful link in `_submit`**

Within the `try` block after `linkWithEmail()` succeeds, add the same cleanup:

```dart
final settings = SettingsService();
await settings.deduplicateWorkoutRoutines();
await SyncQueue.instance.clear();
```

- [ ] **Step 3: Verify the file compiles**

Run: `cd lib && dart analyze pages/auth_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/pages/auth_page.dart
git commit -m "feat: deduplicate routines and clear queue on account link"
```

---

### Task 8: Build and Smoke Test

- [ ] **Step 1: Run full Flutter analysis**

Run: `flutter analyze`
Expected: No errors (pre-existing warnings are OK)

- [ ] **Step 2: Verify build**

Run: `flutter build apk --debug` (or `flutter build ios --debug --no-codesign`)
Expected: Build succeeds

- [ ] **Step 3: Commit any final fixes**

```bash
git add -A
git commit -m "chore: fix analysis issues"
```
