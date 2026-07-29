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
