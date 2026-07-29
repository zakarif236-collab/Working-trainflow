# Offline Strategy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add offline resilience to the workout app with connectivity monitoring, a sync queue for offline community actions, and offline-aware Community feed.

**Architecture:** Three new services (ConnectivityService, SyncQueue, SyncAction model) and one widget (OfflineBanner), plus updates to CommunityFirestoreService and CommunityPage. Core features (timers, settings, workouts) are already local-first and need no changes.

**Tech Stack:** Flutter/Dart, `connectivity_plus: ^6.1.4`, `shared_preferences: ^2.5.3`, `cloud_firestore: ^5.6.5`

## Global Constraints

- Use `connectivity_plus: ^6.1.4` (must be added to pubspec.yaml)
- SharedPreferences for sync queue storage (no Hive)
- Follow existing singleton pattern for services (see `CommunityFirestoreService.instance`)
- All Firestore write methods must catch errors and enqueue SyncActions on failure
- CommunityPage must load cached data immediately when offline instead of showing a spinner

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `lib/models/sync_action.dart` | Create | Data class for queued offline actions |
| `lib/services/connectivity_service.dart` | Create | Singleton monitoring network state |
| `lib/services/sync_queue.dart` | Create | SharedPreferences-backed action queue with replay |
| `lib/widgets/offline_banner.dart` | Create | Material banner showing offline state |
| `pubspec.yaml` | Modify | Add `connectivity_plus: ^6.1.4` |
| `lib/services/community_firestore_service.dart` | Modify | Enqueue SyncAction on Firestore write failures |
| `lib/pages/community_page.dart` | Modify | Offline-first loading + offline banner integration |

---

### Task 1: Add dependency and create SyncAction model

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/models/sync_action.dart`

**Interfaces:**
- Consumes: nothing
- Produces: `SyncAction` model used by SyncQueue

- [ ] **Step 1: Add connectivity_plus to pubspec.yaml**

Insert after line 44 (`video_player`):
```yaml
  connectivity_plus: ^6.1.4
```

- [ ] **Step 2: Create lib/models/sync_action.dart**

```dart
class SyncAction {
  final String type;
  final Map<String, dynamic> params;
  final DateTime createdAt;

  const SyncAction({
    required this.type,
    required this.params,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'type': type,
    'params': params,
    'createdAt': createdAt.millisecondsSinceEpoch,
  };

  factory SyncAction.fromJson(Map<String, dynamic> json) => SyncAction(
    type: json['type'] as String,
    params: Map<String, dynamic>.from(json['params'] as Map),
    createdAt: DateTime.fromMillisecondsSinceEpoch(
      (json['createdAt'] as num).toInt(),
    ),
  );
}
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/models/sync_action.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml lib/models/sync_action.dart
git commit -m "feat: add connectivity_plus dependency and SyncAction model"
```

---

### Task 2: Create ConnectivityService

**Files:**
- Create: `lib/services/connectivity_service.dart`

**Interfaces:**
- Consumes: `SyncAction` model from Task 1
- Produces: `ConnectivityService.instance`, `ConnectivityService.isOnline`, `ConnectivityService.onConnectivityChanged`
- Also calls `SyncQueue.instance.processQueue()` on reconnect (SyncQueue created in Task 3 — method signature: `Future<void> processQueue()`)

- [ ] **Step 1: Create lib/services/connectivity_service.dart**

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();
  bool _isOnline = true;
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool get isOnline => _isOnline;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> initialize() async {
    final result = await _connectivity.checkConnectivity();
    _updateStatus(result);

    _subscription = _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> result) {
    final online = !result.contains(ConnectivityResult.none);
    final wasOffline = !_isOnline;
    _isOnline = online;
    _controller.add(online);

    if (wasOffline && online) {
      _onReconnect();
    }
  }

  void _onReconnect() {
    try {
      SyncQueue.instance.processQueue();
    } catch (_) {}
  }

  void dispose() {
    _subscription?.cancel();
    _controller.close();
  }
}
```

Note: `SyncQueue` is imported and used. The import must be added:
```dart
import 'package:my_app/services/sync_queue.dart';
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/services/connectivity_service.dart`
Expected: No issues found (SyncQueue may show import warning until Task 3 — expected)

- [ ] **Step 3: Commit**

```bash
git add lib/services/connectivity_service.dart
git commit -m "feat: add ConnectivityService for network state monitoring"
```

---

### Task 3: Create SyncQueue

**Files:**
- Create: `lib/services/sync_queue.dart`

**Interfaces:**
- Consumes: `SyncAction` from Task 1, `ConnectivityService.isOnline` from Task 2, `CommunityFirestoreService`
- Produces: `SyncQueue.instance.enqueue()`, `SyncQueue.instance.processQueue()`, `SyncQueue.instance.pendingCount`

- [ ] **Step 1: Create lib/services/sync_queue.dart**

```dart
import 'dart:convert';
import 'package:my_app/models/sync_action.dart';
import 'package:my_app/services/community_firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SyncQueue {
  SyncQueue._();

  static final SyncQueue instance = SyncQueue._();

  static const String _queueKey = 'offline.syncQueue';

  Future<void> enqueue(SyncAction action) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_queueKey));
    queue.add(action.toJson());
    await prefs.setString(_queueKey, jsonEncode(queue));
  }

  Future<int> get pendingCount async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQueue(prefs.getString(_queueKey)).length;
  }

  Future<List<SyncAction>> peek() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodeQueue(prefs.getString(_queueKey))
        .map((raw) => SyncAction.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  Future<void> processQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final queue = _decodeQueue(prefs.getString(_queueKey));
    if (queue.isEmpty) return;

    final remaining = <Map<String, dynamic>>[];
    final firestore = CommunityFirestoreService.instance;

    for (final item in queue) {
      try {
        final action = SyncAction.fromJson(Map<String, dynamic>.from(item));
        await _execute(firestore, action);
      } catch (_) {
        remaining.add(item);
      }
    }

    await prefs.setString(_queueKey, remaining.isEmpty ? '' : jsonEncode(remaining));
  }

  Future<void> _execute(CommunityFirestoreService firestore, SyncAction action) async {
    switch (action.type) {
      case 'like_workout':
        await firestore.toggleLike(
          action.params['workoutId'] as String,
          action.params['isLiked'] as bool,
        );
      case 'save_workout':
        await firestore.toggleSave(
          action.params['workoutId'] as String,
          action.params['currentlySaved'] as bool? ?? false,
        );
      case 'follow_creator':
        await firestore.toggleFollow(
          action.params['creatorId'] as String,
          action.params['isFollowing'] as bool,
        );
      case 'rate_workout':
        await firestore.rateWorkout(
          action.params['workoutId'] as String,
          (action.params['stars'] as num).toInt(),
        );
      case 'add_comment':
        await firestore.addComment(
          action.params['workoutId'] as String,
          action.params['message'] as String,
        );
    }
  }

  List<Map<String, dynamic>> _decodeQueue(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().cast<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/services/sync_queue.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/sync_queue.dart
git commit -m "feat: add SyncQueue for offline action queuing and replay"
```

---

### Task 4: Create OfflineBanner widget

**Files:**
- Create: `lib/widgets/offline_banner.dart`

**Interfaces:**
- Consumes: `ConnectivityService.instance`
- Produces: OfflineBanner widget

- [ ] **Step 1: Create lib/widgets/offline_banner.dart**

```dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:my_app/services/connectivity_service.dart';

class OfflineBanner extends StatefulWidget {
  const OfflineBanner({super.key});

  @override
  State<OfflineBanner> createState() => _OfflineBannerState();
}

class _OfflineBannerState extends State<OfflineBanner> {
  bool _isOffline = false;
  StreamSubscription<bool>? _subscription;

  @override
  void initState() {
    super.initState();
    _isOffline = !ConnectivityService.instance.isOnline;
    _subscription = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (mounted) setState(() => _isOffline = !online);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFB33A3A),
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'You\'re offline. Changes will sync when you\'re back online.',
              style: TextStyle(color: Colors.white, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isOffline = false),
            child: const Icon(Icons.close, color: Colors.white54, size: 18),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run analyzer**

Run: `flutter analyze lib/widgets/offline_banner.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/offline_banner.dart
git commit -m "feat: add OfflineBanner widget"
```

---

### Task 5: Update CommunityFirestoreService with sync queue

**Files:**
- Modify: `lib/services/community_firestore_service.dart`

**Interfaces:**
- Consumes: `SyncQueue.instance.enqueue()` from Task 3
- Produces: Updated Firestore write methods that queue actions on failure

- [ ] **Step 1: Add import for SyncQueue**

Add at top of `community_firestore_service.dart`:
```dart
import 'package:my_app/services/sync_queue.dart';
```

- [ ] **Step 2: Update toggleLike — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': !currentlyLiked},
      ));
    }
```

- [ ] **Step 3: Update toggleFavorite — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': !currentlyFavorited},
      ));
    }
```

- [ ] **Step 4: Update toggleSave — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'save_workout',
        params: {'workoutId': workoutId, 'currentlySaved': currentlySaved},
      ));
    }
```

- [ ] **Step 5: Update rateWorkout — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'rate_workout',
        params: {'workoutId': workoutId, 'stars': rating},
      ));
    }
```

- [ ] **Step 6: Update addComment — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'add_comment',
        params: {'workoutId': workoutId, 'message': message},
      ));
    }
```

- [ ] **Step 7: Update toggleFollow — enqueue on failure**

Replace the empty catch block:
```dart
    } catch (_) {}
```
with:
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'follow_creator',
        params: {'creatorId': creatorId, 'isFollowing': !currentlyFollowing},
      ));
    }
```

- [ ] **Step 8: Update incrementShare — enqueue on failure (optional but consistent)**

For `incrementShare` (line 196-202):
```dart
    } catch (_) {
      await SyncQueue.instance.enqueue(SyncAction(
        type: 'like_workout',
        params: {'workoutId': workoutId, 'isLiked': true},
      ));
    }
```

- [ ] **Step 9: Run analyzer**

Run: `flutter analyze lib/services/community_firestore_service.dart`
Expected: No issues found

- [ ] **Step 10: Commit**

```bash
git add lib/services/community_firestore_service.dart
git commit -m "feat: queue offline community actions via SyncQueue"
```

---

### Task 6: Update CommunityPage for offline-first loading

**Files:**
- Modify: `lib/pages/community_page.dart`

**Interfaces:**
- Consumes: `ConnectivityService.instance` from Task 2, `OfflineBanner` from Task 4

- [ ] **Step 1: Add imports**

Add at top with existing imports:
```dart
import 'package:my_app/services/connectivity_service.dart';
import 'package:my_app/widgets/offline_banner.dart';
```

- [ ] **Step 2: Add connectivity subscription field + init/cleanup**

Add field after `StreamSubscription<List<CommunityWorkout>>? _feedSubscription;` (line 45):
```dart
  StreamSubscription<bool>? _connectivitySubscription;
```

In `initState()`, after `_loadData();` add:
```dart
    _connectivitySubscription = ConnectivityService.instance.onConnectivityChanged.listen((online) {
      if (online) _loadData();
    });
```

In `dispose()`, add:
```dart
    _connectivitySubscription?.cancel();
```

- [ ] **Step 3: Update _loadData to check connectivity first**

Replace the current `_loadData()` method with:
```dart
  Future<void> _loadData() async {
    setState(() => _loading = true);

    _myRoutines = await _settingsService.loadWorkoutBuilderRoutines();

    _feedSubscription?.cancel();

    if (!ConnectivityService.instance.isOnline) {
      final local = await _settingsService.loadCommunityWorkouts();
      if (!mounted) return;
      setState(() {
        _workouts = local;
        _loading = false;
      });
      return;
    }

    _feedSubscription = CommunityFirestoreService.instance.streamWorkouts().listen(
      (workouts) {
        if (!mounted) return;
        print('[CommunityPage] Firestore stream received ${workouts.length} workouts');
        setState(() {
          _workouts = workouts;
          _loading = false;
        });
      },
      onError: (e) async {
        print('[CommunityPage] Firestore stream error: $e — falling back to local');
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

- [ ] **Step 4: Add OfflineBanner at top of the build method**

Find the `build` method (around line 160ish — depends on exact location). At the top of the build's returned widget tree, wrap the body in a Column with the OfflineBanner at top.

Look for the `Scaffold` in the build method and wrap its `body`:

Before build method (around line 160), the body is typically `NestedScrollBar` or similar. Add the OfflineBanner as part of the body column:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ...,
      body: Column(
        children: [
          const OfflineBanner(),
          Expanded(child: /* existing body content */),
        ],
      ),
    );
  }
```

The exact change depends on the current build structure. Open the file and wrap the body content appropriately.

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze lib/pages/community_page.dart`
Expected: No issues found

- [ ] **Step 6: Run full project analysis**

Run: `flutter analyze`
Expected: No issues found (existing errors in widget_test.dart are pre-existing)

- [ ] **Step 7: Commit**

```bash
git add lib/pages/community_page.dart
git commit -m "feat: make CommunityPage offline-first with connectivity check and banner"
```
