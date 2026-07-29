# Offline Strategy for Workout App

## Overview

Add offline resilience to the workout app. Core features (timers, settings, workout builder) are already local-first. The gaps are: no connectivity monitoring, no sync queue for offline community actions, and poor offline fallback on the Community feed.

## Components

### 1. ConnectivityService (`lib/services/connectivity_service.dart`)

Wraps `connectivity_plus` into a singleton.

- `static final ConnectivityService instance` — singleton
- `bool isOnline` — latest known state
- `Stream<bool> onConnectivityChanged` — for widgets to react
- `Future<void> initialize()` — runs initial check + subscribes to `Connectivity().onConnectivityChanged`
- On connectivity restored → triggers `SyncQueue.instance.processQueue()`

**pubspec.yaml** — add `connectivity_plus: ^6.1.4`

### 2. SyncQueue (`lib/services/sync_queue.dart`)

Stores pending offline actions in SharedPreferences (key: `offline.syncQueue`). LIFO queue processed in order.

**SyncAction model:**
```
type: String        // e.g. "like_workout", "save_workout"
params: Map         // e.g. {workoutId: "abc", isLiked: true}
createdAt: int      // millisecondsSinceEpoch
```

**Action types and their params:**
| type | params |
|---|---|
| `like_workout` | `{workoutId, isLiked}` |
| `save_workout` | `{workoutId}` |
| `follow_creator` | `{creatorId, isFollowing}` |
| `rate_workout` | `{workoutId, stars}` |
| `add_comment` | `{workoutId, message}` |

**API:**
- `Future<void> enqueue(SyncAction action)` — append to queue
- `Future<void> processQueue()` — replay all pending actions in order; remove successful ones; keep failed ones for retry
- `Future<List<SyncAction>> peek()` — view pending queue (for UI badge)
- `Future<int> pendingCount` — count of pending actions

### 3. OfflineBanner (`lib/widgets/offline_banner.dart`)

A Material banner widget that listens to `ConnectivityService`.

- Shows: `Icon(Icons.wifi_off) + "You're offline. Changes will sync when you're back online."`
- Auto-hides when connectivity returns
- Can be dismissed manually

### 4. CommunityPage updates (`lib/pages/community_page.dart`)

Currently: shows `CircularProgressIndicator` until Firestore stream emits or errors.

Changed flow:
```
onInit:
  check connectivity
  if offline → load cached data immediately, show banner, skip Firestore stream
  if online → try Firestore stream, on error → fall back to cache + banner
  
on connectivity restored:
  reload Firestore stream
  
on connectivity lost:
  show banner (keep current data)
```

### 5. CommunityFirestoreService updates (`lib/services/community_firestore_service.dart`)

Each write method currently silently catches errors. Change:

```
try {
  await FirebaseFirestore.instance.xxx();
} catch (e) {
  await SyncQueue.instance.enqueue(SyncAction(type, params));
}
```

Methods affected:
- `toggleLike()` → enqueue `like_workout`
- `toggleFavorite()` → enqueue `like_workout` (same as like for local tracking)
- `toggleSave()` → enqueue `save_workout`
- `toggleFollow()` → enqueue `follow_creator`
- `rateWorkout()` → enqueue `rate_workout`
- `addComment()` → enqueue `add_comment`
- `publishWorkout()` → keep current behavior (best-effort; community workouts are cached locally)
- `incrementShare()` — optional (can remain silent fail)

### 6. No changes needed

- Timer / Quick Start / Workout Builder → fully local
- Settings → fully local
- Auth → works with or without (guest mode)
- Music, SFX, voice prompts → fully local
- Notifications → local + FCM

## Files

| Action | File |
|---|---|
| New | `lib/services/connectivity_service.dart` |
| New | `lib/services/sync_queue.dart` |
| New | `lib/models/sync_action.dart` |
| New | `lib/widgets/offline_banner.dart` |
| Modify | `pubspec.yaml` |
| Modify | `lib/pages/community_page.dart` |
| Modify | `lib/services/community_firestore_service.dart` |

## Implementation Order

1. Add `connectivity_plus` dependency
2. Create `SyncAction` model
3. Create `ConnectivityService`
4. Create `SyncQueue`
5. Create `OfflineBanner` widget
6. Update `CommunityFirestoreService` to enqueue on failure
7. Update `CommunityPage` for offline-first loading

## Error Handling

- `SyncQueue.processQueue()` catches individual action failures and leaves them in the queue
- ConnectivityService errors are swallowed (degraded experience vs crashing)
- If SharedPreferences fails, queue operations are best-effort
