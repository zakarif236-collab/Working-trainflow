### Task 2: Startup — Wire Anonymous Sign-In in main.dart

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AuthService.signInAnonymously()`
- Produces: Anonymous user active before `runApp()`

Add anonymous sign-in call after `Firebase.initializeApp(...)` and before the messaging setup:

```dart
try {
  await AuthService().signInAnonymously();
} catch (_) {
  // Anonymous sign-in is best-effort; the app works without it,
  // but some Firestore features will be unavailable until real sign-in.
}
```

Verify the file compiles: `dart analyze lib/main.dart`
Commit with message: `feat: auto sign-in anonymously on startup`
