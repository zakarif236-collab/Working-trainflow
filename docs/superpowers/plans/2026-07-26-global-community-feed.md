# Global Community Feed - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate the community feed from local SharedPreferences to Firestore so shared workouts are visible to all users globally with real-time updates.

**Architecture:** Add a `CommunityFirestoreService` that handles all Firestore CRUD for community workouts. Add a `visibility` field to `CommunityWorkout` (public/followers/private). Replace SharedPreferences reads/writes in `SettingsService` with Firestore calls. Add a real-time stream listener to the community page. Wire push notifications via FCM when a workout is shared publicly.

**Tech Stack:** cloud_firestore (real-time listeners), firebase_messaging (push notifications), Firebase Auth (existing).

## Global Constraints

- Material 3 dark theme with gradient backgrounds
- SharedPreferences remains the source of truth for local settings (not community data)
- Firebase Auth + Google Sign-In already configured — reuse existing auth
- All Firestore writes are best-effort with fallback to local data
- Models already have `toJson()`/`fromJson()` — reuse as-is
- No new packages needed — `cloud_firestore` and `firebase_messaging` already in pubspec.yaml

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/services/community_firestore_service.dart` | Firestore CRUD for community workouts (publish, load, like, comment, follow, stream) |
| `lib/models/workout_models.dart` | Add `visibility` field to `CommunityWorkout` |
| `lib/pages/community_page.dart` | Switch from SharedPreferences to Firestore stream |
| `lib/services/settings_service.dart` | Update `publishCommunityWorkout()` to write to Firestore |
| `lib/services/push_notification_service.dart` | FCM token management + send notification on share |

---

### Task 1: Add Visibility Field to CommunityWorkout Model

**Files:**
- Modify: `lib/models/workout_models.dart` (add `visibility` field to `CommunityWorkout`)

**Interfaces:**
- Produces: `CommunityWorkout.visibility` (String: 'public', 'followers', 'private'), updated `toJson()`/`fromJson()`/`copyWith()`

- [ ] **Step 1: Add visibility enum**

In `workout_models.dart`, after the `WorkoutDifficulty` enum, add:

```dart
enum WorkoutVisibility { public, followers, private }
```

- [ ] **Step 2: Add visibility field to CommunityWorkout**

In the `CommunityWorkout` class constructor, add after `isFollowingCreator`:

```dart
    this.visibility = 'public',
```

Add the field declaration after `isFollowingCreator`:

```dart
  final String visibility;
```

- [ ] **Step 3: Update copyWith**

Add to `copyWith` parameter list:

```dart
    String? visibility,
```

Add to the return statement:

```dart
      visibility: visibility ?? this.visibility,
```

- [ ] **Step 4: Update toJson**

Add to the `toJson()` map:

```dart
      'visibility': visibility,
```

- [ ] **Step 5: Update fromJson**

Add to `fromJson` factory:

```dart
      visibility: json['visibility'] as String? ?? 'public',
```

- [ ] **Step 6: Verify analysis**

Run: `flutter analyze lib/models/workout_models.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/models/workout_models.dart
git commit -m "feat: add visibility field to CommunityWorkout model"
```

---

### Task 2: Create CommunityFirestoreService

**Files:**
- Create: `lib/services/community_firestore_service.dart`

**Interfaces:**
- Consumes: `CommunityWorkout`, `CommunityComment` from Task 1
- Produces: `publishWorkout()`, `loadWorkouts()`, `streamWorkouts()`, `toggleLike()`, `toggleFavorite()`, `addComment()`, `rateWorkout()`, `toggleFollow()`, `incrementShare()`

- [ ] **Step 1: Create the service**

```dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:my_app/models/workout_models.dart';

class CommunityFirestoreService {
  CommunityFirestoreService._();

  static final CommunityFirestoreService instance = CommunityFirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference get _workouts => _db.collection('community_workouts');
  CollectionReference get _users => _db.collection('users');

  // --- Publish ---

  Future<String?> publishWorkout(PublishCommunityWorkoutInput input) async {
    if (_uid == null) return null;

    final user = _auth.currentUser;
    final docRef = _workouts.doc();

    final workout = CommunityWorkout(
      id: docRef.id,
      creatorId: _uid!,
      creatorUsername: user?.displayName ?? 'Anonymous',
      creatorAvatarPath: user?.photoURL ?? '',
      title: input.title,
      description: input.description,
      category: input.category,
      difficulty: input.difficulty,
      tags: input.tags,
      coverImagePath: input.coverImagePath,
      exercises: input.routine.exercises.map((e) => e.name).toList(),
      createdAt: DateTime.now(),
      downloads: 0,
      likes: 0,
      favorites: 0,
      shares: 0,
      ratingsCount: 0,
      ratingsTotal: 0,
      isLiked: false,
      isFavorited: false,
      isSaved: false,
      userRating: 0,
      comments: const [],
      isFollowingCreator: false,
      visibility: 'public',
    );

    try {
      await docRef.set(workout.toJson());
      return docRef.id;
    } catch (_) {
      return null;
    }
  }

  // --- Load ---

  Future<List<CommunityWorkout>> loadWorkouts({int limit = 50}) async {
    try {
      final snapshot = await _workouts
          .where('visibility', isEqualTo: 'public')
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // --- Real-time stream ---

  Stream<List<CommunityWorkout>> streamWorkouts({int limit = 50}) {
    return _workouts
        .where('visibility', isEqualTo: 'public')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  // --- Interactions ---

  Future<void> toggleLike(String workoutId, bool currentlyLiked) async {
    if (_uid == null) return;
    try {
      await _workouts.doc(workoutId).update({
        'likes': FieldValue.increment(currentlyLiked ? -1 : 1),
      });
      // Update user's liked workouts subcollection
      final userLikeDoc = _users.doc(_uid).collection('liked_workouts').doc(workoutId);
      if (currentlyLiked) {
        await userLikeDoc.delete();
      } else {
        await userLikeDoc.set({'likedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  Future<void> toggleFavorite(String workoutId, bool currentlyFavorited) async {
    if (_uid == null) return;
    try {
      await _workouts.doc(workoutId).update({
        'favorites': FieldValue.increment(currentlyFavorited ? -1 : 1),
      });
      final userFavDoc = _users.doc(_uid).collection('favorite_workouts').doc(workoutId);
      if (currentlyFavorited) {
        await userFavDoc.delete();
      } else {
        await userFavDoc.set({'favoritedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  Future<void> incrementShare(String workoutId) async {
    try {
      await _workouts.doc(workoutId).update({
        'shares': FieldValue.increment(1),
      });
    } catch (_) {}
  }

  Future<void> rateWorkout(String workoutId, int rating) async {
    if (_uid == null) return;
    try {
      final ratingDoc = _users.doc(_uid).collection('rated_workouts').doc(workoutId);
      await ratingDoc.set({'rating': rating, 'ratedAt': FieldValue.serverTimestamp()});

      // Recalculate average
      final ratingsSnap = await _users.doc(_uid).collection('rated_workouts').get();
      // For simplicity, update the workout's rating fields directly
      await _workouts.doc(workoutId).update({
        'ratingsCount': FieldValue.increment(1),
        'ratingsTotal': FieldValue.increment(rating),
      });
    } catch (_) {}
  }

  Future<void> addComment(String workoutId, String message) async {
    if (_uid == null) return;
    try {
      final user = _auth.currentUser;
      final commentRef = _workouts.doc(workoutId).collection('comments').doc();

      final comment = CommunityComment(
        id: commentRef.id,
        authorUsername: user?.displayName ?? 'Anonymous',
        message: message,
        createdAt: DateTime.now(),
      );

      await commentRef.set(comment.toJson());
    } catch (_) {}
  }

  Future<void> toggleFollow(String creatorId, bool currentlyFollowing) async {
    if (_uid == null) return;
    try {
      final followDoc = _users.doc(_uid).collection('following').doc(creatorId);
      if (currentlyFollowing) {
        await followDoc.delete();
      } else {
        await followDoc.set({'followedAt': FieldValue.serverTimestamp()});
      }
    } catch (_) {}
  }

  // --- Stats ---

  Future<CreatorCommunityStats> loadCreatorStats(String creatorId) async {
    try {
      final snapshot = await _workouts
          .where('creatorId', isEqualTo: creatorId)
          .get();

      final workouts = snapshot.docs
          .map((doc) => CommunityWorkout.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      final totalDownloads = workouts.fold<int>(0, (sum, w) => sum + w.downloads);
      final totalLikes = workouts.fold<int>(0, (sum, w) => sum + w.likes);
      final totalShares = workouts.fold<int>(0, (sum, w) => sum + w.shares);

      final profileSnap = await _users.doc(creatorId).get();
      final profile = profileSnap.data() as Map<String, dynamic>?;

      return CreatorCommunityStats(
        creatorId: creatorId,
        username: profile?['displayName'] ?? 'Unknown',
        profileImagePath: profile?['profileImagePath'] ?? '',
        bio: profile?['bio'] ?? '',
        totalPublished: workouts.length,
        followers: 0,
        totalDownloads: totalDownloads,
        totalShares: totalShares,
        likesReceived: totalLikes,
        fiveStarRatings: 0,
        badges: const [],
      );
    } catch (_) {
      return CreatorCommunityStats(
        creatorId: creatorId,
        username: 'Unknown',
        totalPublished: 0,
        followers: 0,
        totalDownloads: 0,
        totalShares: 0,
        likesReceived: 0,
        fiveStarRatings: 0,
      );
    }
  }
}
```

- [ ] **Step 2: Verify analysis**

Run: `flutter analyze lib/services/community_firestore_service.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/services/community_firestore_service.dart
git commit -m "feat: add CommunityFirestoreService for global feed"
```

---

### Task 3: Create Push Notification Service for Share Alerts

**Files:**
- Create: `lib/services/push_notification_service.dart`

**Interfaces:**
- Consumes: `CommunityFirestoreService` from Task 2
- Produces: `initialize()`, `sendShareNotification()`, `subscribeToTopic()`

- [ ] **Step 1: Create the service**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> initialize() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFcmToken(token);
      }
      _messaging.onTokenRefresh.listen(_saveFcmToken);
    }

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    await _messaging.subscribeToTopic('global_feed');
  }

  Future<void> _saveFcmToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  void _handleForegroundMessage(RemoteMessage message) {
    // Handle foreground notification if needed
  }

  Future<void> sendShareNotification({
    required String senderName,
    required String workoutTitle,
  }) async {
    try {
      await _db.collection('notifications').add({
        'type': 'workout_shared',
        'senderName': senderName,
        'workoutTitle': workoutTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'topic': 'global_feed',
      });
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}
```

- [ ] **Step 2: Register background handler in main.dart**

In `lib/main.dart`, before `main()`, add:

```dart
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Handle background message
}
```

In `main()`, after `Firebase.initializeApp()`, add:

```dart
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
```

- [ ] **Step 3: Initialize in main.dart**

In `main()`, after Firebase init, add:

```dart
  await PushNotificationService.instance.initialize();
```

- [ ] **Step 4: Verify analysis**

Run: `flutter analyze lib/services/push_notification_service.dart lib/main.dart`
Expected: No errors

- [ ] **Step 5: Commit**

```bash
git add lib/services/push_notification_service.dart lib/main.dart
git commit -m "feat: add push notification service for global feed alerts"
```

---

### Task 4: Wire Publish to Firestore

**Files:**
- Modify: `lib/services/settings_service.dart` (update `publishCommunityWorkout()` to also write to Firestore)

**Interfaces:**
- Consumes: `CommunityFirestoreService` from Task 2, `PushNotificationService` from Task 3

- [ ] **Step 1: Add imports**

At top of `settings_service.dart`, add:

```dart
import 'package:my_app/services/community_firestore_service.dart';
import 'package:my_app/services/push_notification_service.dart';
```

- [ ] **Step 2: Update publishCommunityWorkout**

Find the `publishCommunityWorkout` method. After the existing local save logic, add Firestore publish:

```dart
    // Publish to Firestore for global visibility
    try {
      final firestoreId = await CommunityFirestoreService.instance.publishWorkout(input);
      if (firestoreId != null) {
        // Send push notification
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await PushNotificationService.instance.sendShareNotification(
            senderName: user.displayName ?? 'Someone',
            workoutTitle: input.title,
          );
        }
      }
    } catch (_) {
      // Firestore publish is best-effort
    }
```

- [ ] **Step 3: Verify analysis**

Run: `flutter analyze lib/services/settings_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: wire publish to Firestore with push notification"
```

---

### Task 5: Switch Community Page to Firestore Stream

**Files:**
- Modify: `lib/pages/community_page.dart` (replace SharedPreferences load with Firestore stream)

**Interfaces:**
- Consumes: `CommunityFirestoreService` from Task 2

- [ ] **Step 1: Add import**

At top of `community_page.dart`, add:

```dart
import 'package:my_app/services/community_firestore_service.dart';
```

- [ ] **Step 2: Add stream subscription field**

In the `_CommunityPageState` class, add:

```dart
  StreamSubscription<List<CommunityWorkout>>? _feedSubscription;
```

- [ ] **Step 3: Replace _loadData with stream**

Replace the `_loadData()` method with:

```dart
  Future<void> _loadData() async {
    setState(() => _loading = true);

    // Load local routines for publish dialog
    _myRoutines = await _settingsService.loadWorkoutBuilderRoutines();

    // Subscribe to Firestore stream
    _feedSubscription?.cancel();
    _feedSubscription = CommunityFirestoreService.instance.streamWorkouts().listen(
      (workouts) {
        if (!mounted) return;
        setState(() {
          _workouts = workouts;
          _loading = false;
        });
      },
      onError: (_) async {
        // Fallback to local data on error
        final local = await _settingsService.loadCommunityWorkouts();
        if (!mounted) return;
        setState(() {
          _workouts = local;
          _loading = false;
        });
      },
    );
  }
```

- [ ] **Step 4: Cancel subscription on dispose**

In `dispose()`, add before the existing cleanup:

```dart
    _feedSubscription?.cancel();
```

- [ ] **Step 5: Verify analysis**

Run: `flutter analyze lib/pages/community_page.dart`
Expected: No errors

- [ ] **Step 6: Commit**

```bash
git add lib/pages/community_page.dart
git commit -m "feat: switch community page to Firestore real-time stream"
```

---

### Task 6: Build and Verify

- [ ] **Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 2: Build release APK**

Run: `flutter build apk --release`
Expected: Build succeeds

- [ ] **Step 3: Final commit if any fixups needed**
