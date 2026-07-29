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
