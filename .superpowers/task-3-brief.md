# Task 3: Create Push Notification Service for Share Alerts

## Files
- Create: `lib/services/push_notification_service.dart`
- Modify: `lib/main.dart` (register background handler + initialize service)

## Interfaces
- Consumes: `CommunityFirestoreService` from Task 2 (not directly used yet, but ready for future)
- Produces: `initialize()`, `sendShareNotification()`, `subscribeToTopic()`

## Steps

### Step 1: Create the service

Create `lib/services/push_notification_service.dart` with this exact content:

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
```

### Step 2: Register background handler in main.dart

In `lib/main.dart`, BEFORE the `main()` function, add:

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

### Step 3: Initialize in main.dart

In `main()`, after Firebase init and background handler registration, add:

```dart
  await PushNotificationService.instance.initialize();
```

### Step 4: Verify analysis
Run: `flutter analyze lib/services/push_notification_service.dart lib/main.dart`
Expected: No errors

### Step 5: Commit
```bash
git add lib/services/push_notification_service.dart lib/main.dart
git commit -m "feat: add push notification service for global feed alerts"
```
