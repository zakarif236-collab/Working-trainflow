# Task 4: Wire Publish to Firestore

## Files
- Modify: `lib/services/settings_service.dart` (update `publishCommunityWorkout()` to also write to Firestore)

## Interfaces
- Consumes: `CommunityFirestoreService` from Task 2, `PushNotificationService` from Task 3

## Current Code

The `publishCommunityWorkout` method is at line 276 of `settings_service.dart`. It currently:
1. Validates input
2. Creates a `CommunityWorkout` object
3. Saves to local SharedPreferences
4. Returns the workout

## Steps

### Step 1: Add imports

At top of `settings_service.dart`, add these imports (near the existing imports):

```dart
import 'package:my_app/services/community_firestore_service.dart';
import 'package:my_app/services/push_notification_service.dart';
```

### Step 2: Update publishCommunityWorkout

Find the `publishCommunityWorkout` method. At the end of the method (after `await saveCommunityWorkouts(next);` and before `return workout;`), add:

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

Also add `import 'package:firebase_auth/firebase_auth.dart';` if not already present.

### Step 3: Verify analysis

Run: `flutter analyze lib/services/settings_service.dart`
Expected: No errors

### Step 4: Commit

```bash
git add lib/services/settings_service.dart
git commit -m "feat: wire publish to Firestore with push notification"
```
