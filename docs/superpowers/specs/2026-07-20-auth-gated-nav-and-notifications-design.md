# Auth-Gated Navigation & Community Notifications — Design Spec

## Overview

Restructure the app so the Home page (default timer) is accessible without sign-in, while Mods and Profile pages require authentication. Add real-time follower/like count updates on profiles, an in-app notification center, and real-time push notifications when someone likes or follows a user.

## Requirements

### Navigation gating
- **Signed out**: Bottom nav shows only Home tab (default timer). Mods and Profile tabs are hidden.
- **Signed in**: Bottom nav shows all 3 tabs: Home, Mods, Profile.
- Home page when signed out shows only the timer — no sign-in prompt or CTA.

### Real-time profile updates
- Follower count, like count, and published workout count on the profile page update in real-time when someone likes or follows.

### Notifications
- **In-app notification center**: A bell icon in the app bar with a badge showing unread count. Tapping it opens a notifications list.
- **Push notifications**: Real-time Firebase Cloud Messaging (FCM) push sent to the device when someone likes or follows the user, even when the app is closed.
- Notifications are stored in Firestore under `users/{uid}/notifications/` and also sent as FCM push.

## Architecture

### 1. Conditional Bottom Navigation (`lib/pages/main_shell_page.dart`)

Wrap the nav logic in a `StreamBuilder<User?>` listening to `authStateChanges`.

**When signed out (`user == null`):**
- `IndexedStack` contains only `[HomeTimerPage]`
- `NavigationBar` has 1 destination: Home
- `_selectedIndex` stays at 0

**When signed in (`user != null`):**
- `IndexedStack` contains all 3 pages as today: `[HomeTimerPage, HomePage, FirstPage]`
- `NavigationBar` has 3 destinations: Home, Mods, Profile
- Full existing behavior preserved

```dart
StreamBuilder<User?>(
  stream: authService.authStateChanges,
  builder: (context, snapshot) {
    final user = snapshot.data;
    final signedIn = user != null;

    final pages = <Widget>[
      HomeTimerPage(key: ValueKey(_homeTimerKey), pendingConfig: _pendingWorkoutConfig),
      if (signedIn) HomePage(onStartTraining: _switchToTimerWithConfig),
      if (signedIn) FirstPage(onBackPressed: ...),
    ];

    final destinations = <NavigationDestination>[
      const NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home_rounded),
        label: 'Home',
      ),
      if (signedIn) const NavigationDestination(
        icon: Icon(Icons.grid_view_rounded),
        selectedIcon: Icon(Icons.grid_view),
        label: 'Mods',
      ),
      if (signedIn) const NavigationDestination(
        icon: Icon(Icons.person_outline_rounded),
        selectedIcon: Icon(Icons.person_rounded),
        label: 'Profile',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _selectedIndex.clamp(0, pages.length - 1), children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex.clamp(0, pages.length - 1),
        onDestinationSelected: (index) { ... },
        destinations: destinations,
      ),
    );
  },
)
```

### 2. Notification Service (`lib/services/notification_service.dart`)

New service handling both in-app notifications and push notifications.

```dart
class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Push notification setup
  Future<void> initialize();
  Future<String?> getToken();

  // In-app notifications
  Future<void> sendLikeNotification(String targetUserId, String fromUsername, String workoutTitle);
  Future<void> sendFollowNotification(String targetUserId, String fromUsername);
  Stream<List<AppNotification>> watchNotifications(String uid);
  Future<void> markAsRead(String uid, String notificationId);
  Future<int> getUnreadCount(String uid);
}
```

**FCM token storage**: On sign-in, save FCM token to `users/{uid}/fcmToken`. On sign-out, remove it.

**Push delivery**: When a like or follow happens:
1. Write notification doc to `users/{targetUserId}/notifications/{notificationId}`
2. Read target user's `fcmToken` from Firestore
3. Send FCM push via Firebase Admin SDK (server-side) or HTTP v1 API

Since this is a Flutter app without a custom backend, push notifications will use **Firebase Cloud Functions** triggered by Firestore writes to send FCM messages.

### 3. Notification Data Model

**Firestore collection**: `users/{uid}/notifications/{notificationId}`

| Field | Type | Description |
|-------|------|-------------|
| `type` | String | `"like"` or `"follow"` |
| `fromUserId` | String | UID of the user who triggered it |
| `fromUsername` | String | Display name of the trigger user |
| `workoutTitle` | String | (likes only) Title of the liked workout |
| `createdAt` | Timestamp | When it happened |
| `read` | Boolean | Whether the recipient has seen it |

### 4. Notification UI

**Bell icon**: Added to the AppBar of `FirstPage` (Profile tab). This is the primary location for checking notifications.

- Shows a small red badge with unread count when > 0
- Tapping opens `NotificationPage` — a scrollable list of notifications
- Each notification shows: avatar, "X liked your workout Y" or "X started following you", time ago
- Tapping a notification marks it as read

**`lib/pages/notification_page.dart`**:
- `StreamBuilder<List<AppNotification>>` listening to the notifications collection
- Lists notifications newest-first
- Swipe or tap to mark as read

### 5. Real-Time Profile Stats

**`lib/pages/user_profile_page.dart`** and **`lib/pages/first_page.dart`**:

Replace one-shot Firestore reads with `snapshots()` streams:

```dart
StreamBuilder<DocumentSnapshot>(
  stream: _db.collection('users').doc(creatorId).snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) return loading;
    final data = snapshot.data!.data() as Map<String, dynamic>;
    // Update _stats from data — follower count, likes, etc.
  },
)
```

Also stream the community stats (followers, likes received) from a subcollection or a denormalized stats document.

**Firestore structure for real-time stats** at `users/{uid}`:

| Field | Type | Description |
|-------|------|-------------|
| `followers` | int | Follower count |
| `likesReceived` | int | Total likes received |
| `totalPublished` | int | Published workouts count |

These fields are incremented atomically when a like/follow happens:

```dart
// On follow
await _db.collection('users').doc(targetUid).update({
  'followers': FieldValue.increment(1),
});

// On like
await _db.collection('users').doc(targetUid).update({
  'likesReceived': FieldValue.increment(1),
});
```

## Files to Create

| File | Purpose |
|------|---------|
| `lib/services/notification_service.dart` | FCM setup, notification CRUD, push send |
| `lib/models/notification_model.dart` | `AppNotification` data class |
| `lib/pages/notification_page.dart` | In-app notification list UI |
| `functions/src/index.ts` | Firebase Cloud Function for Firestore→FCM push |

## Files to Modify

| File | Change |
|------|--------|
| `lib/pages/main_shell_page.dart` | Accept `AuthService` parameter, add StreamBuilder for auth-gated nav, conditional tabs |
| `lib/pages/first_page.dart` | Add bell icon, StreamBuilder for real-time stats |
| `lib/pages/user_profile_page.dart` | StreamBuilder for real-time follower/like counts |
| `lib/pages/community_page.dart` | On like/follow: write notification + increment stats |
| `lib/services/settings_service.dart` | Extend `toggleCommunityLike` and `toggleFollowCreator` to also increment Firestore stats and write notification docs (existing local behavior preserved) |
| `lib/main.dart` | Initialize NotificationService, request FCM permissions on sign-in, pass AuthService to MainShellPage |

## Data Flow

```
User A likes User B's workout:
  → settingsService.toggleLike(workoutId)
    → Write like to local data + Firestore
    → Increment B's likesReceived in Firestore (atomic)
    → notificationService.sendLikeNotification(B.uid, A.username, workout.title)
      → Write notification doc to users/{B}/notifications/
      → Cloud Function triggers → sends FCM push to B's deviceToken
  → B's profile page StreamBuilder detects Firestore change → UI updates in real-time
  → B sees notification badge update in real-time via StreamBuilder on bell icon
```

```
User A follows User B:
  → settingsService.toggleFollowCreator(B.uid)
    → Write follow to local data + Firestore
    → Increment B's followers in Firestore (atomic)
    → notificationService.sendFollowNotification(B.uid, A.username)
      → Write notification doc to users/{B}/notifications/
      → Cloud Function triggers → sends FCM push to B's deviceToken
  → B's profile page StreamBuilder detects Firestore change → UI updates in real-time
```

## Firebase Cloud Function (for push delivery)

```typescript
// functions/src/index.ts
import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

admin.initializeApp();

export const onNotificationCreated = functions.firestore
  .document("users/{userId}/notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notif = snap.data();
    const userId = context.params.userId;

    // Get target user's FCM token
    const userDoc = await admin.firestore().doc(`users/${userId}`).get();
    const fcmToken = userDoc.data()?.fcmToken;
    if (!fcmToken) return;

    const title = notif.type === "like"
      ? `${notif.fromUsername} liked your workout`
      : `${notif.fromUsername} started following you`;

    await admin.messaging().send({
      token: fcmToken,
      notification: { title, body: notif.workoutTitle || "" },
      data: { type: notif.type, notificationId: snap.id },
    });
  });
```

## Testing Strategy

- Unit test `NotificationService` methods with mocked Firestore
- Widget test conditional nav rendering for signed-in vs signed-out states
- Widget test notification list with mock stream data
- Integration test: like a workout → verify notification doc created in Firestore → verify FCM token receives push
- Manual test: sign out → verify only Home tab visible → sign in → verify all tabs appear
- Manual test: like from device A → notification appears on device B in real-time
