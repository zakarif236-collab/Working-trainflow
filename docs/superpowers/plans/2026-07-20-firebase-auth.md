# Firebase Email/Password Authentication Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add email/password sign-in and sign-up with Firestore profile sync and an auth gate that blocks the main app until authenticated.

**Architecture:** Plain AuthService class wrapping FirebaseAuth, a UserProfileService for Firestore CRUD, a single toggle auth page, and a StreamBuilder auth gate in main.dart. Follows existing codebase patterns (plain service classes, setState, no DI framework).

**Tech Stack:** Flutter, Firebase Auth, Cloud Firestore, SharedPreferences (existing)

## Global Constraints

- No new dependencies — `firebase_auth` and `cloud_firestore` already in pubspec.yaml
- Dark theme palette: background `0xFF090D14`, cards `0xFF141B2D` / `0xFF1A2439`, accents coral `0xFFFF8A1E`, green `0xFF86E3A4`, blue `0xFF9BC4FF`
- Services are plain Dart classes instantiated directly in widgets (no Provider, no DI)
- All pages use `StatefulWidget` + `setState()`
- Private child widgets prefixed with `_` in the same file as parent

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `lib/services/auth_service.dart` | Create | FirebaseAuth wrapper (sign in, sign up, sign out, auth state stream) |
| `lib/services/user_profile_service.dart` | Create | Firestore user profile CRUD |
| `lib/pages/auth_page.dart` | Create | Single toggle page for sign-in / sign-up |
| `lib/main.dart` | Modify | Add auth gate StreamBuilder, pass AuthService to MyApp |
| `lib/pages/first_page.dart` | Modify | Load profile from Firestore on sign-in, save profile to Firestore on edit |
| `lib/services/settings_service.dart` | Modify | Add method to populate WorkoutInsights from Firestore data |

---

### Task 1: AuthService

**Files:**
- Create: `lib/services/auth_service.dart`

**Interfaces:**
- Consumes: `package:firebase_auth/firebase_auth.dart`
- Produces: `AuthService` class with `authStateChanges`, `currentUserId`, `signIn`, `signUp`, `signOut`

- [ ] **Step 1: Create auth_service.dart with the full implementation**

```dart
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  String? get currentUserId => _auth.currentUser?.uid;

  Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signUp(String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await credential.user?.updateDisplayName(displayName.trim());
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/services/auth_service.dart`
Expected: No errors (warnings OK)

- [ ] **Step 3: Commit**

```bash
git add lib/services/auth_service.dart
git commit -m "feat: add AuthService wrapping FirebaseAuth"
```

---

### Task 2: UserProfileService

**Files:**
- Create: `lib/services/user_profile_service.dart`

**Interfaces:**
- Consumes: `package:cloud_firestore/cloud_firestore.dart`
- Produces: `UserProfileService` class with `createProfile`, `getProfile`, `updateProfile`

- [ ] **Step 1: Create user_profile_service.dart with the full implementation**

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfileService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createProfile(String uid, String email, String displayName) async {
    await _db.collection('users').doc(uid).set({
      'displayName': displayName.trim(),
      'email': email.trim(),
      'bio': '',
      'profileImagePath': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'totalWorkouts': 0,
      'totalSeconds': 0,
      'currentStreakDays': 0,
      'bestStreakDays': 0,
    });
  }

  Future<Map<String, dynamic>?> getProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<void> updateProfile(String uid, Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/services/user_profile_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/user_profile_service.dart
git commit -m "feat: add UserProfileService for Firestore profile CRUD"
```

---

### Task 3: Auth Page UI

**Files:**
- Create: `lib/pages/auth_page.dart`

**Interfaces:**
- Consumes: `AuthService` (passed via constructor)
- Produces: `AuthPage` widget

- [ ] **Step 1: Create auth_page.dart with the full implementation**

```dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/services/auth_service.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.authService});

  final AuthService authService;

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _formKey.currentState?.reset();
    });
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isLoading = true);

    try {
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
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      final message = _mapError(e.code);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Something went wrong. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _mapError(String code) {
    switch (code) {
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'network-request-failed':
        return 'Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.fitness_center_rounded,
                      size: 64,
                      color: Color(0xFFFF8A1E),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isSignUp ? 'Create Account' : 'Welcome Back',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isSignUp
                          ? 'Sign up to start training'
                          : 'Sign in to continue training',
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    if (_isSignUp) ...[
                      TextFormField(
                        controller: _displayNameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Display Name',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@') || !value.contains('.')) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                          onPressed: () {
                            setState(() => _obscurePassword = !_obscurePassword);
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    if (_isSignUp) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        validator: (value) {
                          if (_isSignUp && value != _passwordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF8A1E),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isSignUp ? 'Create Account' : 'Sign In',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: _toggleMode,
                      child: Text(
                        _isSignUp
                            ? 'Already have an account? Sign In'
                            : "Don't have an account? Sign Up",
                        style: const TextStyle(
                          color: Color(0xFFFF8A1E),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/pages/auth_page.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/pages/auth_page.dart
git commit -m "feat: add AuthPage with sign-in/sign-up toggle"
```

---

### Task 4: Auth Gate in main.dart

**Files:**
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `AuthService` (created in main)
- Produces: Updated `MyApp` that receives `AuthService` and wraps app in `StreamBuilder`

- [ ] **Step 1: Update main.dart to add auth gate**

Replace the full content of `lib/main.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:my_app/config/gemini_config.dart';
import 'package:my_app/pages/auth_page.dart';
import 'package:my_app/pages/community_page.dart';
import 'package:my_app/pages/first_page.dart';
import 'package:my_app/pages/main_shell_page.dart';
import 'package:my_app/pages/user_profile_page.dart';
import 'package:my_app/pages/workout_builder_page.dart';
import 'package:my_app/pages/workout_builder_player_page.dart';
import 'package:my_app/pages/workout_timer_page.dart';
import 'package:my_app/services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  assert(() {
    if (GeminiConfig.isConfigured) {
      debugPrint('Gemini voice-over key is configured.');
    } else {
      debugPrint('Gemini voice-over key is missing.');
    }
    return true;
  }());

  final authService = AuthService();
  runApp(MyApp(authService: authService));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.authService});

  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFFFF8A1E),
    );

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Workout Builder',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D14),
      ),
      home: StreamBuilder(
        stream: authService.authStateChanges,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.hasData) {
            return const MainShellPage();
          }
          return AuthPage(authService: authService);
        },
      ),
      routes: {
        '/profile': (_) => const FirstPage(),
        '/workout': (_) => const WorkoutTimerPage(),
        '/workout-builder': (_) => const WorkoutBuilderPage(),
        '/my-workouts': (_) => const WorkoutBuilderPage(showBuilder: false),
        '/workout-builder-player': (_) => const WorkoutBuilderPlayerPage(),
        '/community': (_) => const CommunityPage(),
        '/user-profile': (_) => const UserProfilePage(creatorId: ''),
      },
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/main.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/main.dart
git commit -m "feat: add auth gate to main.dart with StreamBuilder"
```

---

### Task 5: Firestore Profile Integration in SettingsService

**Files:**
- Modify: `lib/services/settings_service.dart`

**Interfaces:**
- Consumes: `WorkoutInsights` (existing class)
- Produces: `loadInsightsFromFirestore` and `saveInsightsToFirestore` methods

- [ ] **Step 1: Add import for cloud_firestore at the top of settings_service.dart**

Add after the existing imports (line 4):

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
```

- [ ] **Step 2: Add Firestore methods to SettingsService class**

Add these methods inside the `SettingsService` class, after the `saveBio` method (after line 744):

```dart
  Future<void> saveInsightsToFirestore(String uid, WorkoutInsights insights) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'displayName': insights.displayName,
        'bio': insights.bio,
        'profileImagePath': insights.profileImagePath,
        'totalWorkouts': insights.totalWorkouts,
        'totalSeconds': insights.totalSeconds,
        'currentStreakDays': insights.currentStreakDays,
        'bestStreakDays': insights.bestStreakDays,
        'lastWorkoutAt': insights.lastWorkoutAt?.millisecondsSinceEpoch,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Firestore write is best-effort; local SharedPreferences remains the source of truth on failure.
    }
  }

  Future<WorkoutInsights?> loadInsightsFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;

      final lastWorkoutMillis = data['lastWorkoutAt'] as int?;
      return WorkoutInsights(
        displayName: (data['displayName'] as String?) ?? WorkoutInsights.defaults.displayName,
        profileImagePath: (data['profileImagePath'] as String?) ?? '',
        bio: (data['bio'] as String?) ?? '',
        totalWorkouts: (data['totalWorkouts'] as num?)?.toInt() ?? 0,
        totalSeconds: (data['totalSeconds'] as num?)?.toInt() ?? 0,
        currentStreakDays: (data['currentStreakDays'] as num?)?.toInt() ?? 0,
        bestStreakDays: (data['bestStreakDays'] as num?)?.toInt() ?? 0,
        lastWorkoutAt: lastWorkoutMillis == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(lastWorkoutMillis),
      );
    } catch (_) {
      return null;
    }
  }
```

- [ ] **Step 3: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/services/settings_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add Firestore read/write methods to SettingsService"
```

---

### Task 6: Profile Page Firestore Sync

**Files:**
- Modify: `lib/pages/first_page.dart`

**Interfaces:**
- Consumes: `AuthService` (to get current user UID), `SettingsService.loadInsightsFromFirestore`, `SettingsService.saveInsightsToFirestore`
- Produces: Profile loads from Firestore on init, saves to Firestore on edit

- [ ] **Step 1: Add import for auth_service.dart**

Add after the existing imports (after line 8):

```dart
import 'package:my_app/services/auth_service.dart';
```

- [ ] **Step 2: Update _FirstPageState to load from Firestore on init**

In the `_FirstPageState` class, update `_loadInsights` to also fetch from Firestore. Replace the `_loadInsights` method (lines 46-93) with:

```dart
  Future<void> _loadInsights() async {
    try {
      final authService = AuthService();
      final uid = authService.currentUserId;

      WorkoutInsights? insights;
      if (uid != null) {
        insights = await _settingsService.loadInsightsFromFirestore(uid);
      }

      insights ??= await _settingsService.loadInsights();

      final sessions = await _settingsService.loadRecentSessions(limit: 30);
      final communityStats = await _settingsService.loadMyCommunityStats();
      final appLifetimeDays = await _settingsService.loadAppLifetimeDays();
      if (!mounted) {
        return;
      }
      setState(() {
        _insights = insights!;
        _communityStats = communityStats;
        _recentSessions = sessions;
        _appLifetimeDays = appLifetimeDays;
        _loadingInsights = false;
      });

      try {
        await ReminderService.instance.maybeSendDailyWorkoutReminder(
          _settingsService,
        );
      } catch (_) {
        // Notifications are best-effort and should not interrupt home screen rendering.
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _insights = WorkoutInsights.defaults;
        _communityStats = const CreatorCommunityStats(
          creatorId: 'user.local',
          username: 'Athlete',
          profileImagePath: '',
          bio: '',
          totalPublished: 0,
          followers: 0,
          totalDownloads: 0,
          totalShares: 0,
          likesReceived: 0,
          fiveStarRatings: 0,
          badges: [],
        );
        _recentSessions = const [];
        _appLifetimeDays = 1;
        _loadingInsights = false;
      });
    }
  }
```

- [ ] **Step 3: Update _promptForDisplayName to also save to Firestore**

Replace the `_promptForDisplayName` method (lines 96-156) with:

```dart
  Future<void> _promptForDisplayName() async {
    final nameController = TextEditingController(text: _insights.displayName);
    final bioController = TextEditingController(text: _insights.bio);

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2235),
          title: const Text('Edit Profile'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                autofocus: true,
                maxLength: 24,
                decoration: const InputDecoration(
                  hintText: 'Display name',
                  labelText: 'Name',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioController,
                maxLength: 120,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Tell others about yourself...',
                  labelText: 'Bio',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop({
                'name': nameController.text,
                'bio': bioController.text,
              }),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    await _settingsService.saveDisplayName(result['name'] ?? '');
    await _settingsService.saveBio(result['bio'] ?? '');

    final authService = AuthService();
    final uid = authService.currentUserId;
    if (uid != null) {
      final updatedInsights = await _settingsService.loadInsights();
      await _settingsService.saveInsightsToFirestore(uid, updatedInsights);
    }

    if (mounted) {
      await _loadInsights();
    }
  }
```

- [ ] **Step 4: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/pages/first_page.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/pages/first_page.dart
git commit -m "feat: sync profile data to/from Firestore in profile page"
```

---

### Task 7: Sign Out Button

**Files:**
- Modify: `lib/pages/first_page.dart`

**Interfaces:**
- Consumes: `AuthService.signOut()`
- Produces: Sign out button in the profile page header

- [ ] **Step 1: Add a sign out button to the profile page**

In the `_FirstPageState.build` method, add a sign out button. Find the `Align` widget with the back arrow (around line 328) and add a sign out button next to it. Replace the back button section:

Replace:
```dart
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton.filledTonal(
                      onPressed: () {
                        if (widget.onBackPressed != null) {
                          widget.onBackPressed!();
                          return;
                        }
                        Navigator.of(context).maybePop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFF253454),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
```

With:
```dart
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () {
                          if (widget.onBackPressed != null) {
                            widget.onBackPressed!();
                            return;
                          }
                          Navigator.of(context).maybePop();
                        },
                        icon: const Icon(Icons.arrow_back_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF253454),
                          foregroundColor: Colors.white,
                        ),
                      ),
                      const Spacer(),
                      IconButton.filledTonal(
                        onPressed: () async {
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              backgroundColor: const Color(0xFF1A2235),
                              title: const Text('Sign Out'),
                              content: const Text('Are you sure you want to sign out?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Sign Out'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await AuthService().signOut();
                          }
                        },
                        icon: const Icon(Icons.logout_rounded),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF253454),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
```

- [ ] **Step 2: Verify no analysis errors**

Run: `cd C:\Users\hp\my_app && dart analyze lib/pages/first_page.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/pages/first_page.dart
git commit -m "feat: add sign out button to profile page"
```

---

### Task 8: Verify Build

- [ ] **Step 1: Run flutter analyze on the full project**

Run: `cd C:\Users\hp\my_app && flutter analyze`
Expected: No errors

- [ ] **Step 2: Verify the app builds for Android**

Run: `cd C:\Users\hp\my_app && flutter build apk --debug`
Expected: Build succeeds

- [ ] **Step 3: Commit any fixes if needed**

```bash
git add -A
git commit -m "fix: resolve analysis warnings for auth feature"
```
