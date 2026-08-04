# Workout Progress Firestore Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** After each completed workout, sync the user's progress summary and recent 30-session history to their Firestore `users/{uid}` doc, and restore it on the Profile page preferring whichever source is newer.

**Architecture:** A single merged Firestore document write carries the stat fields plus each session under a dotted path `recentSessions.<completedAtMillis>` so offline writes from two devices merge at the nested-key level. Two pure top-level helpers (`sessionsToFirestoreMap`, `pickNewerInsights`) keep the conflict/trim/staleness logic unit-testable without Firebase. Sync is best-effort and gated on a real Firebase session; a `firestore.rules` file is added to the repo so access is auditable.

**Tech Stack:** Flutter/Dart, `cloud_firestore` 5.x, `firebase_auth` 5.x, `shared_preferences`, `flutter_test`.

## Global Constraints

- Sync gating: write to Firestore only when `FirebaseAuth.instance.currentUser?.uid != null`. Offline device-UID users are skipped (no junk docs).
- Sessions are stored as a map keyed by `completedAt` millis, written via dotted paths `recentSessions.<millis>`, not an array.
- All writes use `SetOptions(merge: true)` and must never clobber `displayName`, `bio`, or `profileImagePath`.
- Local session list is trimmed to the newest 30 before pushing; restore trims to the newest 30 too.
- Writes are best-effort: swallow failures (keep the existing pattern — the `saveInsightsToFirestore` catch comment, and `debugPrint` log for the new sync method).
- Staleness: on Profile load, prefer the source (local vs Firestore) with the newer `lastWorkoutAt`.
- No retry queue, no analytics — explicitly out of scope for this feature (no `firebase_analytics` package in `pubspec.yaml`).
- `firestore.rules` is drafted and committed but deployed manually (`firebase deploy --only firestore:rules`) and only after user review.
- Verification commands: `flutter analyze` must stay clean of new issues; `flutter test` must pass.
- Follow existing code style: no new imports beyond what each task lists; use `const` where possible; keep comments minimal and matching surrounding style.

---

### Task 1: Add `sessionsToFirestoreMap` helper + unit tests

Pure helper that turns the local session list into the timestamp-keyed Firestore map (sorted newest-first, trimmed to 30). No Firebase involvement.

**Files:**
- Modify: `lib/services/settings_service.dart` (append helper at end of file, after line 1109)
- Test: `test/workout_progress_sync_test.dart` (create)

**Interfaces:**
- Produces: top-level function `Map<String, dynamic> sessionsToFirestoreMap(List<WorkoutSessionEntry> sessions)`. Keys are `'<completedAt.millisecondsSinceEpoch>'` strings; values are `session.toJson()` maps; newest 30 kept, sorted descending by `completedAt`.

- [ ] **Step 1: Write the failing test**

Create `test/workout_progress_sync_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';

void main() {
  WorkoutSessionEntry entry(int millis) => WorkoutSessionEntry(
        completedAt: DateTime.fromMillisecondsSinceEpoch(millis),
        durationSeconds: 30,
        sets: 4,
        workSeconds: 240,
        restSeconds: 180,
        intensity: WorkoutIntensity.medium,
      );

  test('builds map keyed by completedAt millis, sorted newest first', () {
    final map = sessionsToFirestoreMap([
      entry(1000),
      entry(3000),
      entry(2000),
    ]);

    expect(map.keys.toList(), ['3000', '2000', '1000']);
    expect(map['2000']!['durationSeconds'], 30);
  });

  test('trims to the newest 30 sessions', () {
    final sessions = List.generate(35, (i) => entry(1000 + i));

    final map = sessionsToFirestoreMap(sessions);

    expect(map.length, 30);
    expect(map.keys.first, '1034');
    expect(map.keys.last, '1005');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: FAIL — compilation error "Undefined name 'sessionsToFirestoreMap'".

- [ ] **Step 3: Write minimal implementation**

Append to the end of `lib/services/settings_service.dart` (after line 1109, the `_kMusicDuckingEnabled` const):

```dart
Map<String, dynamic> sessionsToFirestoreMap(List<WorkoutSessionEntry> sessions) {
  final sorted = List<WorkoutSessionEntry>.from(sessions)
    ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  return {
    for (final s in sorted.take(30))
      '${s.completedAt.millisecondsSinceEpoch}': s.toJson(),
  };
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: PASS — both tests green.

- [ ] **Step 5: Commit**

```bash
git add test/workout_progress_sync_test.dart lib/services/settings_service.dart
git commit -m "feat: add timestamp-keyed session map helper for Firestore sync"
```

---

### Task 2: Add `syncWorkoutProgressToFirestore` + hook into `recordWorkoutCompletion`

Adds the best-effort Firestore writer and calls it at the end of `recordWorkoutCompletion()`. The new method is internally try/catch-guarded so a missing Firebase session or a failed write never breaks workout completion.

**Files:**
- Modify: `lib/services/settings_service.dart` (imports at top; new method after `loadRecentSessions` at line 908; one line at end of `recordWorkoutCompletion` at line 978)
- Test: `test/workout_progress_sync_test.dart` (append)

**Interfaces:**
- Consumes: `sessionsToFirestoreMap` (Task 1), `loadInsights()` (existing), `loadRecentSessions({limit})` (existing).
- Produces:
  - Top-level `Map<String, dynamic> buildWorkoutSyncData(WorkoutInsights insights, List<WorkoutSessionEntry> sessions)` — builds the stat fields (`totalWorkouts`, `totalSeconds`, `currentStreakDays`, `bestStreakDays`, `lastWorkoutAt`) plus one `recentSessions.<millis>` dotted key per session (via `sessionsToFirestoreMap`). Does NOT include `displayName`/`bio`/`profileImagePath`/`updatedAt`. Pure and unit-testable.
  - `Future<void> syncWorkoutProgressToFirestore()` on `SettingsService`. Reads local insights + recent sessions (limit 30), writes `users/{uid}` with `buildWorkoutSyncData(...)` plus `updatedAt`, all via one `set(..., merge: true)`. No-op when `FirebaseAuth.instance.currentUser?.uid` is null.

- [ ] **Step 1: Write the failing tests**

Append to `test/workout_progress_sync_test.dart` (before the closing `}` of `main`):

```dart
  test('syncWorkoutProgressToFirestore is a no-op without Firebase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.syncWorkoutProgressToFirestore();
    // Must not throw even though Firebase Auth is unavailable in this test.
  });

  test('recordWorkoutCompletion records locally and tolerates sync failure',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.recordWorkoutCompletion(
      600,
      when: DateTime(2026, 8, 3, 10),
    );

    final insights = await settings.loadInsights();
    expect(insights.totalWorkouts, 1);
    expect(insights.totalSeconds, 600);

    final sessions = await settings.loadRecentSessions(limit: 30);
    expect(sessions.length, 1);
    expect(sessions.first.durationSeconds, 600);
  });

  test('buildWorkoutSyncData includes stats and dotted session keys', () {
    final data = buildWorkoutSyncData(
      insightsAt(DateTime(2026, 8, 3), total: 7),
      [entry(1000)],
    );

    expect(data['totalWorkouts'], 7);
    expect(data['recentSessions.1000'], isNotNull);
    expect(data.keys.any((k) => k.startsWith('recentSessions.')), isTrue);
    expect(data.containsKey('updatedAt'), isFalse);
    expect(data.containsKey('displayName'), isFalse);
  });
```

Add the import to `test/workout_progress_sync_test.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: FAIL — compilation error "Undefined name 'syncWorkoutProgressToFirestore'" (and "Undefined name 'buildWorkoutSyncData'").

- [ ] **Step 3: Add the flutter/foundation import**

In `lib/services/settings_service.dart`, add to the imports at the top (alphabetical, after the `cloud_firestore` import):

```dart
import 'package:flutter/foundation.dart';
```

- [ ] **Step 4: Implement the buildWorkoutSyncData helper and the sync method**

In `lib/services/settings_service.dart`, insert the sync method between `loadRecentSessions` (ends at line 908) and `shouldSendMissedWorkoutReminder` (starts at line 910):

```dart
  Future<void> syncWorkoutProgressToFirestore() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;

      final insights = await loadInsights();
      final sessions = await loadRecentSessions(limit: 30);

      final data = buildWorkoutSyncData(insights, sessions);
      data['updatedAt'] = FieldValue.serverTimestamp();

      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('SettingsService: workout progress sync failed: $e');
    }
  }
```

Append to the end of `lib/services/settings_service.dart` (after the `sessionsToFirestoreMap` helper from Task 1):

```dart
Map<String, dynamic> buildWorkoutSyncData(
  WorkoutInsights insights,
  List<WorkoutSessionEntry> sessions,
) {
  final data = <String, dynamic>{
    'totalWorkouts': insights.totalWorkouts,
    'totalSeconds': insights.totalSeconds,
    'currentStreakDays': insights.currentStreakDays,
    'bestStreakDays': insights.bestStreakDays,
    'lastWorkoutAt': insights.lastWorkoutAt?.millisecondsSinceEpoch,
  };
  for (final entry in sessionsToFirestoreMap(sessions).entries) {
    data['recentSessions.${entry.key}'] = entry.value;
  }
  return data;
}
```

- [ ] **Step 5: Call it from recordWorkoutCompletion**

In `lib/services/settings_service.dart`, after the last line of `recordWorkoutCompletion` (line 978: `await prefs.setString(_kRecentSessions, jsonEncode(updated));`), add:

```dart

    await syncWorkoutProgressToFirestore();
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: PASS — the no-op test and the completion test both green.

- [ ] **Step 7: Commit**

```bash
git add test/workout_progress_sync_test.dart lib/services/settings_service.dart
git commit -m "feat: sync workout progress to Firestore after each workout"
```

---

### Task 3: Include session history in `saveInsightsToFirestore`

Extends the existing profile-edit sync so it writes `recentSessions.<millis>` too, keeping the doc shape identical to the post-workout sync. It reuses `buildWorkoutSyncData` (Task 2), so no new payload-building logic is added and no new test is needed — the shared helper is already covered in Task 2 and this task is a pure refactor of the write path (verified by `flutter analyze` + the full suite).

**Files:**
- Modify: `lib/services/settings_service.dart` (`saveInsightsToFirestore` at lines 842-858)

**Interfaces:**
- Consumes: `buildWorkoutSyncData` (Task 2), `loadRecentSessions({limit})` (existing).
- Produces: no signature change — `Future<void> saveInsightsToFirestore(String uid, WorkoutInsights insights)` now also writes `recentSessions.<millis>` keys via `buildWorkoutSyncData`.

- [ ] **Step 1: Rewrite saveInsightsToFirestore**

Replace the whole body of `saveInsightsToFirestore` (lines 842-858) with:

```dart
  Future<void> saveInsightsToFirestore(String uid, WorkoutInsights insights) async {
    try {
      final data = <String, dynamic>{
        'displayName': insights.displayName,
        'bio': insights.bio,
        'profileImagePath': insights.profileImagePath,
        ...buildWorkoutSyncData(insights, await loadRecentSessions(limit: 30)),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
            data,
            SetOptions(merge: true),
          );
    } catch (_) {
      // Firestore write is best-effort; local SharedPreferences remains the source of truth on failure.
    }
  }
```

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: no new issues in `lib/services/settings_service.dart`.

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS — all tests green (Task 1/2 tests exercise the shared helper).

- [ ] **Step 4: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: include session history in profile-edit Firestore sync"
```

---

### Task 4: Add `loadRecentSessionsFromFirestore` + `pickNewerInsights` helper + tests

Adds the restore-side primitives: a Firestore reader for the session map, and a pure staleness resolver.

**Files:**
- Modify: `lib/services/settings_service.dart` (new method after `loadInsightsFromFirestore` at line 883; new top-level helper at end of file)
- Test: `test/workout_progress_sync_test.dart` (append)

**Interfaces:**
- Consumes: `WorkoutSessionEntry.fromJson` (existing).
- Produces:
  - `Future<List<WorkoutSessionEntry>> loadRecentSessionsFromFirestore(String uid)` on `SettingsService` — reads `recentSessions` map, converts values to entries, sorts descending by `completedAt`, returns newest 30; empty list on any failure.
  - Top-level `WorkoutInsights pickNewerInsights(WorkoutInsights local, WorkoutInsights? remote)` — returns `remote` when it is non-null and strictly newer by `lastWorkoutAt`; otherwise `local` (also when remote is null, or local is null-sourced but remote also has no `lastWorkoutAt`, or local is newer).

- [ ] **Step 1: Write the failing tests**

Append to `test/workout_progress_sync_test.dart`:

```dart
  test('pickNewerInsights prefers the source with the newer last workout',
      () {
    final local = insightsAt(DateTime(2026, 8, 3), total: 5);
    final olderRemote = insightsAt(DateTime(2026, 8, 2), total: 4);
    expect(pickNewerInsights(local, olderRemote), same(local));

    final newerRemote = insightsAt(DateTime(2026, 8, 4), total: 6);
    expect(pickNewerInsights(local, newerRemote), same(newerRemote));
  });

  test('pickNewerInsights falls back to local when remote is null or empty',
      () {
    final local = insightsAt(DateTime(2026, 8, 3), total: 5);
    expect(pickNewerInsights(local, null), same(local));
    expect(pickNewerInsights(local, insightsAt(null, total: 0)), same(local));
  });

  test('pickNewerInsights uses remote on a fresh device with no local workouts',
      () {
    final emptyLocal = insightsAt(null, total: 0);
    final remote = insightsAt(DateTime(2026, 8, 3), total: 4);
    expect(pickNewerInsights(emptyLocal, remote), same(remote));
  });
```

Add the helper above `main()` (inside the test file, below the `entry` helper):

```dart
  WorkoutInsights insightsAt(DateTime? lastAt, {required int total}) =>
      WorkoutInsights(
        displayName: 'Athlete',
        profileImagePath: '',
        bio: '',
        totalWorkouts: total,
        totalSeconds: 0,
        currentStreakDays: 0,
        bestStreakDays: 0,
        lastWorkoutAt: lastAt,
      );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: FAIL — compilation error "Undefined name 'pickNewerInsights'".

- [ ] **Step 3: Implement the loader method**

In `lib/services/settings_service.dart`, insert after `loadInsightsFromFirestore` (which ends at line 883):

```dart
  Future<List<WorkoutSessionEntry>> loadRecentSessionsFromFirestore(String uid) async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final raw = doc.data()?['recentSessions'];
      if (raw is! Map) return const [];

      final sessions = raw.entries
          .map((entry) {
            final value = entry.value;
            if (value is! Map) return null;
            return WorkoutSessionEntry.fromJson(Map<String, dynamic>.from(value));
          })
          .nonNulls
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

      return sessions.take(30).toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
```

- [ ] **Step 4: Implement the staleness helper**

Append to the end of `lib/services/settings_service.dart` (after the `sessionsToFirestoreMap` helper from Task 1):

```dart
WorkoutInsights pickNewerInsights(WorkoutInsights local, WorkoutInsights? remote) {
  if (remote == null) return local;
  final localAt = local.lastWorkoutAt;
  final remoteAt = remote.lastWorkoutAt;
  if (localAt == null && remoteAt == null) return local;
  if (localAt == null) return remote;
  if (remoteAt == null) return local;
  return remoteAt.isAfter(localAt) ? remote : local;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/workout_progress_sync_test.dart`
Expected: PASS — all tests green.

- [ ] **Step 6: Commit**

```bash
git add test/workout_progress_sync_test.dart lib/services/settings_service.dart
git commit -m "feat: restore session history from Firestore with staleness resolution"
```

---

### Task 5: Restore newer source + Firestore sessions on Profile load

Rewires `FirstPage._loadInsights()` to load local and remote insights, pick the newer one, and load sessions from Firestore first with a local fallback.

**Files:**
- Modify: `lib/pages/first_page.dart` (`_loadInsights` at lines 47-102)

**Interfaces:**
- Consumes: `pickNewerInsights` (Task 4), `loadRecentSessionsFromFirestore(String uid)` (Task 4), existing `loadInsights()`, `loadInsightsFromFirestore(uid)`, `loadRecentSessions({limit})`, `loadMyCommunityStats()`, `loadAppLifetimeDays()`.
- Produces: `_loadInsights()` (no signature change) that sets `_insights` to the newer of local/remote and `_recentSessions` to Firestore sessions when non-empty, else local sessions.

- [ ] **Step 1: Modify _loadInsights**

Replace lines 47-102 of `lib/pages/first_page.dart` with:

```dart
  Future<void> _loadInsights() async {
    try {
      final authService = AuthService();
      final uid = authService.currentUserId;

      final localInsights = await _settingsService.loadInsights();
      final remoteInsights = await _settingsService.loadInsightsFromFirestore(uid);
      final insights = pickNewerInsights(localInsights, remoteInsights);

      var sessions = await _settingsService.loadRecentSessionsFromFirestore(uid);
      if (sessions.isEmpty) {
        sessions = await _settingsService.loadRecentSessions(limit: 30);
      }

      final communityStats = await _settingsService.loadMyCommunityStats();
      final appLifetimeDays = await _settingsService.loadAppLifetimeDays();
      if (!mounted) {
        return;
      }
      setState(() {
        _insights = insights;
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

Note: `_insights = insights` no longer needs the old `insights!` null-assert because `pickNewerInsights` returns non-null.

- [ ] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: no new issues (the 11 pre-existing `info` lints in unrelated files may still be present; nothing in `first_page.dart`/`settings_service.dart`).

- [ ] **Step 3: Run the full test suite**

Run: `flutter test`
Expected: PASS — all 16 existing tests plus the new sync tests.

- [ ] **Step 4: Commit**

```bash
git add lib/pages/first_page.dart
git commit -m "feat: restore newer workout insights and session history on profile load"
```

---

### Task 6: Sync on app launch and resume

Pushes any offline workout progress at startup and whenever the app returns to the foreground.

**Files:**
- Modify: `lib/main.dart` (imports; call after PushNotification init near line 73; listener after `runApp` at line 84)

**Interfaces:**
- Consumes: `SettingsService.syncWorkoutProgressToFirestore()` (Task 2).
- Produces: no signature changes. `main()` now triggers one best-effort sync at launch and registers an `AppLifecycleListener` whose `onResume` triggers a sync.

- [ ] **Step 1: Add the import**

In `lib/main.dart`, add to the imports (near the other `my_app/services` imports):

```dart
import 'package:my_app/services/settings_service.dart';
```

- [ ] **Step 2: Sync on launch**

In `lib/main.dart`, after the `PushNotificationService` init block (after line 73, before the `assert` at line 75), add:

```dart
  await SettingsService().syncWorkoutProgressToFirestore();
```

- [ ] **Step 3: Sync on resume**

In `lib/main.dart`, after `runApp(MyApp(authService: authService));` (line 84) and before the `addPostFrameCallback` block (line 85), add:

```dart
  AppLifecycleListener(
    onResume: () => SettingsService().syncWorkoutProgressToFirestore(),
  );
```

The listener registers itself with `SchedulerBinding`, which keeps it alive for the app lifetime; it does not need to be stored in a variable.

- [ ] **Step 4: Run the analyzer**

Run: `flutter analyze`
Expected: no new issues in `lib/main.dart`.

- [ ] **Step 5: Run the full test suite**

Run: `flutter test`
Expected: PASS — the widget tests in `test/widget_test.dart` pump `MyApp` directly and never call `main()`, so they are unaffected.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart
git commit -m "feat: sync workout progress on app launch and resume"
```

---

### Task 7: Add version-controlled `firestore.rules`

Drafts a security-rules file covering every collection the app reads/writes, restricted to the minimum access each feature needs. Deployment is manual and only after user review.

**Files:**
- Create: `firestore.rules` (repo root)

**Interfaces:**
- Produces: `firestore.rules` (rules_version 2) that the user reviews and later deploys with `firebase deploy --only firestore:rules`.

- [ ] **Step 1: Confirm the access matrix with the user**

Before writing rules, confirm with the user that the access matrix below matches how they intend the app's data to be protected:

| Collection | Read | Write |
| --- | --- | --- |
| `users/{uid}` (profile + stats + fcmToken) | any signed-in user (needed to show other creators' profiles on community stats) | owner only |
| `users/{uid}/*` subcollections (liked_workouts, favorite_workouts, savedWorkouts, rated_workouts, following) | owner only | owner only |
| `community_workouts/{id}` | any signed-in user | create/update by any signed-in user (likes/favorites/ratings/shares update the doc); delete by creator or admin email |
| `community_workouts/{id}/comments/{cid}` | any signed-in user | create by any signed-in user |
| `notifications/{id}` | none | create by any signed-in user (app enqueues share notifications) |

- [ ] **Step 2: Write the rules file**

Create `firestore.rules` at the repo root:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Profile/stats/token doc: readable by any signed-in user (community
    // stats read other creators' profiles), writable only by the owner.
    match /users/{uid} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == uid;

      // Private per-user collections (likes, favorites, saved, ratings,
      // follows) are owner-only.
      match /{document=**} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }

    // Community workouts: any signed-in user may browse or publish, and may
    // update (like/favorite/save/rate/share all update the workout doc).
    // Delete is restricted to the author or the admin account.
    match /community_workouts/{workoutId} {
      allow read, create: if request.auth != null;
      allow update: if request.auth != null;
      allow delete: if request.auth != null &&
          (resource.data.creatorId == request.auth.uid ||
           request.auth.token.email == 'kingslayer.et@gmail.com');

      match /comments/{commentId} {
        allow read, create: if request.auth != null;
      }
    }

    // Share notifications are enqueued by the app; nothing reads them in-app.
    match /notifications/{notificationId} {
      allow create: if request.auth != null;
    }
  }
}
```

- [ ] **Step 3: Commit the draft**

```bash
git add firestore.rules
git commit -m "chore: draft Firestore security rules"
```

- [ ] **Step 4: Report for user review**

Tell the user: the rules draft is committed but **not deployed**. Ask them to review it (especially the admin-email delete exception and the community `update`/`create` scope), and to deploy manually when ready with:

```bash
firebase deploy --only firestore:rules
```

After deploy, verify community feed, publishing, notifications, and workout sync all still work.

---

## Self-Review

**Spec coverage:**
- §1 Sync after each workout → Task 2 (`recordWorkoutCompletion` → `syncWorkoutProgressToFirestore`, dotted-path merged write, 30-trim, Firebase-session gate, best-effort).
- §2 Background sync on launch and resume → Task 6 (launch call + `AppLifecycleListener.onResume`).
- §3 Include session history in profile saves → Task 3.
- §4 Restore history on Profile load → Task 4 (`loadRecentSessionsFromFirestore`) + Task 5 (Firestore-first, local fallback).
- §5 Prefer newer source → Task 4 (`pickNewerInsights`) + Task 5.
- §6 Version-controlled rules → Task 7 (collections enumerated, owner read/write for `users/{uid}`, manual deploy).
- Testing section (analyze clean, manual device A→B restore, offline resume push, 35+ trim, multi-device merge) → Tasks 1-6 automated coverage for trim/merge/staleness/no-op; manual checks itemized in Task 7 Step 4 and noted in final verification below.

**Placeholder scan:** no TBD/TODO; every code step has full code; commands have expected output.

**Type consistency:** `sessionsToFirestoreMap(List<WorkoutSessionEntry>) → Map<String, dynamic>` used in Tasks 1, 2, 3; `buildWorkoutSyncData(WorkoutInsights, List<WorkoutSessionEntry>) → Map<String, dynamic>` used in Tasks 2, 3; `pickNewerInsights(WorkoutInsights, WorkoutInsights?) → WorkoutInsights` used in Task 5; `loadRecentSessionsFromFirestore(String uid) → Future<List<WorkoutSessionEntry>>` used in Task 5; method names match across tasks.

**Pre-flight decisions (user-approved, 2026-08-03):**
- Tasks 2-3 share a tested `buildWorkoutSyncData` helper (no duplicated stat-field map); Task 3's vacuous smoke test was removed and replaced by real helper assertions in Task 2.
- Task 7 rules access matrix approved as drafted.

## Final Verification (after all tasks)

- [ ] `flutter analyze` clean of new issues
- [ ] `flutter test` all pass (16 pre-existing + new `workout_progress_sync_test.dart`)
- [ ] Manual: workout on device A (signed in) → Firestore `users/{uid}` shows fresh stats + `recentSessions`; new device signed in as same account → Profile shows restored stats/history
- [ ] Manual offline: complete workout with no connection, then resume app → missed workout appears in Firestore
- [ ] Manual trim: 35+ workouts → only newest 30 sessions restored
- [ ] Manual multi-device: offline workouts on two devices, sync both → Firestore holds sessions from both; restore shows merged trimmed history
- [ ] Manual rules: after review/deploy, community feed, publishing, notifications, and sync still work
