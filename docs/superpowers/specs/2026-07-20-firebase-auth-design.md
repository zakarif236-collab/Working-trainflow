# Firebase Email/Password Authentication — Design Spec

## Overview

Add sign-in and sign-up to the workout app using Firebase Email/Password authentication. User profiles sync to Firestore. An auth gate blocks the main app until the user is signed in.

## Requirements

- Email + password sign-in and sign-up (no social logins)
- Single auth page with toggle between sign-in and sign-up modes
- Auth gate: app shows login screen first, main app only after sign-in
- User profile data syncs to Firestore (name, bio, avatar, stats)
- Existing local SharedPreferences data serves as offline fallback
- No new dependencies — uses already-declared `firebase_auth` and `cloud_firestore`

## Architecture

### AuthService (`lib/services/auth_service.dart`)

Thin wrapper around `FirebaseAuth`. Plain Dart class, instantiated in widgets (matches existing service pattern).

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> signIn(String email, String password);
  Future<void> signUp(String email, String password, String displayName);
  Future<void> signOut();
}
```

- `signIn` calls `_auth.signInWithEmailAndPassword`
- `signUp` calls `_auth.createUserWithEmailAndPassword`, then `_auth.currentUser.updateDisplayName(displayName)
- `signOut` calls `_auth.signOut()`
- All methods throw `FirebaseAuthException` on failure — the AuthPage catches these in a try/catch and maps error codes to user-friendly `SnackBar` messages per the error mapping table below

### UserProfileService (`lib/services/user_profile_service.dart`)

Handles Firestore read/write for user profiles. Bridges to existing `SettingsService`.

```dart
class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createProfile(String uid, String email, String displayName);
  Future<Map<String, dynamic>?> getProfile(String uid);
  Future<void> updateProfile(String uid, Map<String, dynamic> data);
}
```

**Firestore document structure** at `users/{uid}`:
| Field | Type | Default |
|-------|------|---------|
| `displayName` | String | (from sign-up) |
| `email` | String | (from sign-up) |
| `bio` | String | `''` |
| `profileImagePath` | String | `''` |
| `createdAt` | Timestamp | server timestamp |
| `updatedAt` | Timestamp | server timestamp |
| `totalWorkouts` | int | `0` |
| `totalSeconds` | int | `0` |
| `currentStreakDays` | int | `0` |
| `bestStreakDays` | int | `0` |

### Auth Page (`lib/pages/auth_page.dart`)

Single page with two modes: Sign In and Sign Up.

**UI layout:**
- Dark themed (app palette — deep blue `0xFF090D14` background, warm coral accents)
- App logo/title at top
- Email `TextFormField`
- Password `TextFormField` (obscured)
- Confirm password field (sign-up mode only)
- Display name field (sign-up mode only)
- Primary action button ("Sign In" / "Create Account")
- Toggle text at bottom: "Don't have an account? Sign Up" / "Already have an account? Sign In"
- `SnackBar` for error messages

**Validation:**
- Email: required, valid email format
- Password: required, min 6 characters
- Display name (sign-up): required, min 2 characters
- Confirm password must match password

**Firebase error mapping:**
| Error Code | User Message |
|------------|-------------|
| `wrong-password`, `user-not-found`, `invalid-credential` | "Invalid email or password" |
| `email-already-in-use` | "An account already exists with this email" |
| `weak-password` | "Password must be at least 6 characters" |
| `network-request-failed` | "Check your connection and try again" |
| Other | "Something went wrong. Please try again." |

### Auth Gate (`lib/main.dart`)

Modify `main.dart` to wrap the `MaterialApp` in a `StreamBuilder<User?>`:

```dart
StreamBuilder<User?>(
  stream: authService.authStateChanges,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (snapshot.hasData) {
      return const MainShellPage();
    }
    return const AuthPage();
  },
)
```

The `AuthService` instance is created in `main()` and passed down (or accessed via a simple constructor parameter to `MyApp`).

## Files to Create

| File | Purpose |
|------|---------|
| `lib/services/auth_service.dart` | FirebaseAuth wrapper |
| `lib/services/user_profile_service.dart` | Firestore profile CRUD |
| `lib/pages/auth_page.dart` | Sign-in/up toggle page |

## Files to Modify

| File | Change |
|------|--------|
| `lib/main.dart` | Add auth gate StreamBuilder, create AuthService instance |
| `lib/services/settings_service.dart` | Add method to populate from Firestore data on sign-in |
| `lib/pages/user_profile_page.dart` | Update save to also write to Firestore via UserProfileService |

## Data Flow

```
App Launch
  → Firebase.initializeApp()
  → StreamBuilder listens to authStateChanges
    → No user → AuthPage
      → Sign Up: createUser → createProfile in Firestore → auth gate switches to app
      → Sign In: signInWithEmailAndPassword → load profile from Firestore into SettingsService → auth gate switches to app
    → Has user → MainShellPage
      → Profile page reads/writes via SettingsService (local) + UserProfileService (Firestore)
```

## Migration Path

- Existing local-only users have data in SharedPreferences with `creatorId = 'user.local'`
- On first sign-in after this feature, `UserProfileService.getProfile(uid)` returns `null` (no Firestore doc yet)
- When `getProfile` returns null, the app reads `WorkoutInsights` from `SettingsService` (SharedPreferences) and calls `UserProfileService.createProfile()` to seed the Firestore document
- After that, Firestore is the source of truth, SharedPreferences is offline cache
- On subsequent sign-ins, `getProfile` returns Firestore data, which is written into `SettingsService` fields

## Testing Strategy

- Unit test AuthService methods with mocked FirebaseAuth
- Unit test UserProfileService with mocked Firestore
- Widget test AuthPage form validation and toggle behavior
- Manual test: sign up → sign out → sign in → verify profile loads
