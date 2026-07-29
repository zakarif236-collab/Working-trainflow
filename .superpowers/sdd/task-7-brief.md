### Task 7: Wire Linking Conflict Resolution in AuthSheet

**Files:**
- Modify: `lib/pages/auth_page.dart`

**Interfaces:**
- Consumes: `SyncQueue.clear()`, `SettingsService.deduplicateWorkoutRoutines()`
- Produces: Post-link cleanup after successful anonymous → permanent account upgrade

**Changes:**

1. Add imports (after existing imports at top):

```dart
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/sync_queue.dart';
```

2. In `_signInWithGoogle`, add cleanup inside the `if (widget.authService.isAnonymous)` block after `linkWithGoogle()`:

```dart
if (widget.authService.isAnonymous) {
  await widget.authService.linkWithGoogle();
  final settings = SettingsService();
  await settings.deduplicateWorkoutRoutines();
  await SyncQueue.instance.clear();
} else {
  await widget.authService.signInWithGoogle();
}
```

3. In `_submit`, add cleanup inside the `if (widget.authService.isAnonymous)` block after the display name update:

```dart
if (widget.authService.isAnonymous) {
  await widget.authService.linkWithEmail(
    _emailController.text,
    _passwordController.text,
  );
  if (_isSignUp) {
    await FirebaseAuth.instance.currentUser?.updateDisplayName(_displayNameController.text);
  }
  final settings = SettingsService();
  await settings.deduplicateWorkoutRoutines();
  await SyncQueue.instance.clear();
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
```

Run `dart analyze lib/pages/auth_page.dart`
Commit: `feat: deduplicate routines and clear queue on account link`
