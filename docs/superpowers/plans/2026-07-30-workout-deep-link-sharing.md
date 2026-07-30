# Workout Deep Link Sharing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a share button on builder completion + deep link sharing via `fitpulse://workout/{id}`

**Architecture:** Two-pronged add-on: (1) Share button on builder completion overlay publishes to Firestore and opens native OS share sheet. (2) `app_links` listener at app startup catches incoming `fitpulse://` links, fetches the workout from Firestore, and pushes the builder player directly.

**Tech Stack:** Flutter, Firestore, `app_links` (deep link handling), `share_plus` (native OS share sheet)

## Global Constraints

- `fitpulse://` custom URL scheme (no domain needed)
- Reuses existing `CommunityFirestoreService` for Firestore storage
- Only shared/published workouts are linkable (no private workout links)
- Existing `_shareWorkout` in `community_page.dart` must also get native share sheet

---

### Task 1: Add packages + platform config

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `ios/Runner/Info.plist`

**Interfaces:**
- Consumes: nothing
- Produces: platform-level deep link registration for `fitpulse://`

- [ ] **Step 1: Add packages to pubspec.yaml**

Add under `dependencies:` (alphabetically, after existing entries):

```yaml
  app_links: ^6.4.0
  share_plus: ^10.1.4
```

- [ ] **Step 2: Add fitpulse:// intent filter to AndroidManifest.xml**

Insert inside the `<activity>` block, after the existing `<intent-filter>` (line 37):

```xml
            <intent-filter>
                <action android:name="android.intent.action.VIEW"/>
                <category android:name="android.intent.category.DEFAULT"/>
                <category android:name="android.intent.category.BROWSABLE"/>
                <data android:scheme="fitpulse"/>
            </intent-filter>
```

- [ ] **Step 3: Add fitpulse URL scheme to iOS Info.plist**

Insert before the closing `</dict>` at line 74:

```xml
	<key>CFBundleURLTypes</key>
	<array>
		<dict>
			<key>CFBundleTypeRole</key>
			<string>Editor</string>
			<key>CFBundleURLName</key>
			<string>com.trainflow22.app</string>
			<key>CFBundleURLSchemes</key>
			<array>
				<string>fitpulse</string>
			</array>
		</dict>
	</array>
```

- [ ] **Step 4: Install packages**

Run: `flutter pub get`
Expected: Packages installed without errors.

- [ ] **Step 5: Commit**

```bash
git add pubspec.yaml android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist pubspec.lock
git commit -m "feat: add app_links, share_plus, and fitpulse:// scheme registration"
```

---

### Task 2: Add `shareRoutine` method to CommunityFirestoreService

**Files:**
- Modify: `lib/services/community_firestore_service.dart`
- Modify: `lib/models/workout_models.dart` (add factory to `PublishCommunityWorkoutInput`)

**Interfaces:**
- Consumes: `WorkoutBuilderRoutine` (already exists)
- Produces: `Future<String>` returning the Firestore document ID

This method saves a builder routine as a community workout in Firestore with sensible defaults (routine name as title, no description/cover, default category and difficulty).

- [ ] **Step 1: Add a convenience factory to `PublishCommunityWorkoutInput`**

In `lib/models/workout_models.dart`, add inside the class before the closing `}` at line 573:

```dart
  factory PublishCommunityWorkoutInput.fromRoutine(WorkoutBuilderRoutine routine) {
    return PublishCommunityWorkoutInput(
      title: routine.name,
      description: '',
      category: 'General',
      difficulty: WorkoutDifficulty.beginner,
      tags: const [],
      coverImagePath: '',
      routine: routine,
    );
  }
```

- [ ] **Step 2: Add `shareRoutine` method to `CommunityFirestoreService`**

In `lib/services/community_firestore_service.dart`, add after `deleteWorkout` (line 238):

```dart
  Future<String?> shareRoutine(WorkoutBuilderRoutine routine) async {
    if (_uid == null) return null;
    try {
      final input = PublishCommunityWorkoutInput.fromRoutine(routine);
      return await publishWorkout(input);
    } catch (_) {
      return null;
    }
  }
```

- [ ] **Step 3: Commit**

```bash
git add lib/services/community_firestore_service.dart lib/models/workout_models.dart
git commit -m "feat: add shareRoutine method and fromRoutine factory"
```

---

### Task 3: Add share button to builder completion overlay

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `CommunityFirestoreService.shareRoutine()`, `Share.share()` from share_plus
- Produces: Build player with share button on completion overlay

Add a "Share" button to `_BuilderCompletionOverlay` that:
1. Publishes the routine to Firestore (if not already)
2. Copies `fitpulse://workout/{firestoreId}` to clipboard
3. Opens OS share sheet via `share_plus`
4. Shows success snackbar

- [ ] **Step 1: Add imports to workout_builder_player_page.dart**

Add after line 13 (`import 'package:my_app/services/workout_foreground_service.dart';`):

```dart
import 'package:my_app/services/community_firestore_service.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
```

- [ ] **Step 2: Add `_shareWorkout` method to `_WorkoutBuilderPlayerPageState`**

Add after `_toggleMusicControls` (or any existing method, around line 230):

```dart
  Future<void> _shareWorkout() async {
    final routine = _routine;
    if (routine == null) return;

    final firestoreId = await CommunityFirestoreService.instance.shareRoutine(routine);

    if (!mounted) return;

    if (firestoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share workout. Check your connection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final link = 'fitpulse://workout/$firestoreId';
    await Clipboard.setData(ClipboardData(text: link));
    await Share.share('Try my workout "${routine.name}"! $link');

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout shared! Link copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
```

- [ ] **Step 3: Add `onShare` callback to `_BuilderCompletionOverlay`**

Change the constructor (line 1240-1245):

```dart
  const _BuilderCompletionOverlay({
    required this.totalSeconds,
    required this.completedExercises,
    required this.routineName,
    required this.onDone,
    required this.onShare,
  });

  final int totalSeconds;
  final int completedExercises;
  final String routineName;
  final VoidCallback onDone;
  final VoidCallback onShare;
```

- [ ] **Step 4: Add Share button to overlay build method**

In `_BuilderCompletionOverlay.build`, add after the Done `ElevatedButton` (line 1358, before closing Column):

```dart
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: widget.onShare,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
```

- [ ] **Step 5: Update `_BuilderCompletionOverlay` usage in build method**

At line 897, pass `onShare` callback:

```dart
            if (_isComplete)
              _BuilderCompletionOverlay(
                totalSeconds: _totalSeconds,
                completedExercises: _timeline.where((p) => p.type == _BuilderPhaseType.work).length,
                routineName: routine.name,
                onDone: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                },
                onShare: _shareWorkout,
              ),
```

- [ ] **Step 6: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat: add share button to builder completion overlay"
```

---

### Task 4: Update community page share to use native share sheet

**Files:**
- Modify: `lib/pages/community_page.dart`

**Interfaces:**
- Consumes: `SharePlus.instance.share()` from share_plus
- Produces: OS share sheet opens when tapping share on community posts

Update the existing `_shareWorkout` in `community_page.dart` to also open the native OS share sheet (not just clipboard copy).

- [ ] **Step 1: Add share_plus import to community_page.dart**

Add after the existing imports (around line 8):

```dart
import 'package:share_plus/share_plus.dart';
```

- [ ] **Step 2: Update `_shareWorkout` to open native share sheet**

Replace lines 191-212:

```dart
  Future<void> _shareWorkout(CommunityWorkout workout) async {
    if (!await _requireAuth()) return;
    final link = 'fitpulse://workout/${workout.id}';
    final shareText = 'Try "${workout.title}" by @${workout.creatorUsername}! $link';
    await Clipboard.setData(ClipboardData(text: shareText));
    await Share.share(shareText);
    if (!mounted) return;
    setState(() {
      _workouts = _workouts.map((w) {
        if (w.id != workout.id) return w;
        return w.copyWith(shares: w.shares + 1);
      }).toList();
    });
    CommunityFirestoreService.instance.incrementShare(workout.id);
    _settingsService.incrementCommunityShare(workout.id);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share link copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
```

Key changes:
- Link format changed from `fitpulse://community/{id}` to `fitpulse://workout/{id}` (consistent format)
- Added `SharePlus.instance.share()` call

- [ ] **Step 3: Commit**

```bash
git add lib/pages/community_page.dart
git commit -m "feat: update community share to use native share sheet and consistent link format"
```

---

### Task 5: Add deep link listener and workout loader

**Files:**
- Create: `lib/services/deep_link_service.dart`
- Modify: `lib/main.dart`

**Interfaces:**
- Consumes: `app_links` package, `CommunityFirestoreService`, `Navigator`
- Produces: When `fitpulse://workout/{id}` is received, fetches the workout and navigates to builder player

- [ ] **Step 1: Create deep link service**

Create `lib/services/deep_link_service.dart`:

```dart
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/community_firestore_service.dart';

class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  GlobalKey<NavigatorState>? _navigatorKey;

  void dispose() {
    _sub?.cancel();
    _navigatorKey = null;
  }

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    _navigatorKey = navigatorKey;

    // Handle cold start (app opened from link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleUri(initialUri);
      }
    } catch (_) {}

    // Handle warm start (app already running, link received)
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });
  }

  void _handleUri(Uri uri) {
    if (uri.scheme != 'fitpulse') return;
    if (uri.host != 'workout') return;

    final workoutId = uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    if (workoutId == null || workoutId.isEmpty) return;

    _loadAndNavigate(workoutId);
  }

  Future<void> _loadAndNavigate(String workoutId) async {
    final navigatorKey = _navigatorKey;
    if (navigatorKey == null) return;

    try {
      final doc = await CommunityFirestoreService.instance.fetchWorkoutById(workoutId);
      if (doc == null) return;

      final context = navigatorKey.currentContext;
      if (context == null) return;

      final routine = WorkoutBuilderRoutine(
        id: doc.id,
        name: doc.title,
        createdAt: doc.createdAt,
        exercises: doc.exercises,
      );

      Navigator.of(context).pushNamed(
        '/workout-builder-player',
        arguments: routine,
      );
    } catch (_) {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not load shared workout.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
```

- [ ] **Step 2: Add `fetchWorkoutById` to `CommunityFirestoreService`**

In `lib/services/community_firestore_service.dart`, add after `shareRoutine`:

```dart
  Future<CommunityWorkout?> fetchWorkoutById(String workoutId) async {
    try {
      final doc = await _workouts.doc(workoutId).get();
      if (!doc.exists) return null;
      return CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
```

- [ ] **Step 3: Wire deep link service in main.dart**

Add import (after line 14):

```dart
import 'package:my_app/services/deep_link_service.dart';
```

Add a global navigator key variable after the imports (before `@pragma`):

```dart
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
```

Replace `runApp(MyApp(authService: authService));` with:

```dart
  runApp(MyApp(authService: authService));
  WidgetsBinding.instance.addPostFrameCallback((_) {
    DeepLinkService.instance.init(navigatorKey);
  });
```

In `MaterialApp.build`, add `navigatorKey: navigatorKey` after line 87:

```dart
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Workout Builder',
      theme: base.copyWith(
        scaffoldBackgroundColor: const Color(0xFF090D14),
      ),
      home: const MainShellPage(),
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
```

**No changes needed to `MyApp` class structure** — it stays a `StatelessWidget` since the navigator key is global.

- [ ] **Step 4: Commit**

```bash
git add lib/services/deep_link_service.dart lib/services/community_firestore_service.dart lib/main.dart
git commit -m "feat: add deep link service and fetchWorkoutById for link handling"
```

---

### Task 6: Verify and build

**Files:**
- Run: `flutter analyze`
- Run: `flutter build apk --release`

- [ ] **Step 1: Analyze**

Run: `flutter analyze`
Expected: No errors (pre-existing info-level warnings only).

- [ ] **Step 2: Build release APK**

Run: `flutter build apk --release`
Expected: Build succeeds, APK at `build/app/outputs/flutter-apk/app-release.apk`

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "chore: finalize deep link sharing feature"
```
