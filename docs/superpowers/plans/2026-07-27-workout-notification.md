# Workout Notification Service Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Professional persistent notification for all timer modes with foreground service, action buttons, and background timer survival.

**Architecture:** Foreground service via `flutter_background_service` runs timer in background isolate. Notification shows workout info + action buttons. MethodChannel communicates between notification actions and timer.

**Tech Stack:** flutter_background_service, flutter_background_service_android, flutter_local_notifications, Android foreground service

## Global Constraints

- Flutter 3.44.2, Dart 3.12.2
- Must work on Android API 26+ (min SDK 26)
- Timer must survive app backgrounding and phone lock screen
- One unified notification system for all 3 timer modes
- No memory leaks or analyzer warnings

---

### Task 1: Add dependencies and Android permissions

**Files:**
- Modify: `pubspec.yaml`
- Modify: `android/app/src/main/AndroidManifest.xml`
- Modify: `android/app/build.gradle`

**Interfaces:**
- Consumes: existing pubspec.yaml, AndroidManifest.xml
- Produces: flutter_background_service available, FOREGROUND_SERVICE + WAKE_LOCK permissions

- [ ] **Step 1: Add flutter_background_service to pubspec.yaml**

In `pubspec.yaml`, add under dependencies:

```yaml
  flutter_background_service: ^5.1.0
  flutter_background_service_android: ^6.3.0
```

- [ ] **Step 2: Add Android permissions to AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` tag, before `<application>`:

```xml
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

- [ ] **Step 3: Add foreground service type to AndroidManifest.xml**

In `android/app/src/main/AndroidManifest.xml`, inside `<application>` tag, add before `</application>`:

```xml
        <service
            android:name="id.flutter.flutter_background_service.BackgroundService"
            android:foregroundServiceType="specialUse"
            android:exported="false" />
```

- [ ] **Step 4: Run flutter pub get**

Run: `flutter pub get`
Expected: Success

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/`
Expected: No new issues

- [ ] **Step 6: Commit**

```bash
git add pubspec.yaml android/
git commit -m "feat: add flutter_background_service dependency and Android permissions"
```

---

### Task 2: Create WorkoutForegroundService

**Files:**
- Create: `lib/services/workout_foreground_service.dart`

**Interfaces:**
- Consumes: `flutter_background_service`, `flutter_background_service_android`
- Produces: `WorkoutForegroundService.start()`, `.stop()`, `.update()`, `.onAction` stream

- [ ] **Step 1: Create WorkoutForegroundService**

Create `lib/services/workout_foreground_service.dart`:

```dart
import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:my_app/services/music_service.dart';

class WorkoutForegroundService {
  WorkoutForegroundService._();

  static final WorkoutForegroundService instance = WorkoutForegroundService._();

  static const _channelId = 'workout_foreground';
  static const _channelName = 'Workout Timer';
  static const _notificationId = 888;

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static const _actionStreamController = StreamController<String>.broadcast();
  Stream<String> get onAction => _actionStreamController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  // Current workout state for notification
  String _workoutName = 'Workout';
  String _exerciseName = '';
  int _remainingSeconds = 0;
  int _currentSet = 1;
  int _totalSets = 3;
  bool _isPaused = false;
  bool _isMusicPlaying = false;

  /// Start the foreground service and show notification
  Future<void> start({
    required String workoutName,
    required String exerciseName,
    required int remainingSeconds,
    required int currentSet,
    required int totalSets,
    required bool isMusicPlaying,
  }) async {
    if (_isRunning) return;

    _workoutName = workoutName;
    _exerciseName = exerciseName;
    _remainingSeconds = remainingSeconds;
    _currentSet = currentSet;
    _totalSets = totalSets;
    _isPaused = false;
    _isMusicPlaying = isMusicPlaying;

    await _initLocalNotifications();
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: _channelId,
        initialNotificationTitle: _workoutName,
        initialNotificationContent: _exerciseName,
        foregroundServiceNotificationId: _notificationId,
      ),
      iOSConfiguration: const iOSConfiguration(
        autoStart: false,
      ),
    );

    await _service.startService();
    _isRunning = true;

    await _showNotification();
  }

  /// Stop the foreground service and remove notification
  Future<void> stop() async {
    if (!_isRunning) return;

    _service.invoke('stop');
    _isRunning = false;

    await _localNotifications.cancel(_notificationId);
  }

  /// Update notification with new workout state
  Future<void> update({
    String? exerciseName,
    int? remainingSeconds,
    int? currentSet,
    int? totalSets,
    bool? isPaused,
    bool? isMusicPlaying,
  }) async {
    if (exerciseName != null) _exerciseName = exerciseName;
    if (remainingSeconds != null) _remainingSeconds = remainingSeconds;
    if (currentSet != null) _currentSet = currentSet;
    if (totalSets != null) _totalSets = totalSets;
    if (isPaused != null) _isPaused = isPaused;
    if (isMusicPlaying != null) _isMusicPlaying = isMusicPlaying;

    if (_isRunning) {
      await _showNotification();
    }
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
  }

  /// Show/update the persistent notification
  Future<void> _showNotification() async {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final setStr = 'Set $_currentSet/$_totalSets';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Shows workout progress and controls',
      importance: Importance.high,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      icon: '@mipmap/ic_launcher',
      color: const Color(0xFFFF8A1E),
      actions: <AndroidNotificationAction>[
        if (_isPaused)
          const AndroidNotificationAction('resume', 'Resume', showsUserInterface: false)
        else
          const AndroidNotificationAction('pause', 'Pause', showsUserInterface: false),
        const AndroidNotificationAction('skip', 'Skip', showsUserInterface: false),
        const AndroidNotificationAction('stop', 'Stop', showsUserInterface: false),
        if (_isMusicPlaying)
          const AndroidNotificationAction('music_stop', 'Music Off', showsUserInterface: false)
        else
          const AndroidNotificationAction('music_toggle', 'Music', showsUserInterface: false),
      ],
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      _notificationId,
      _workoutName,
      '$_exerciseName • $setStr • $timeStr',
      details,
    );
  }

  /// Background service entry point (runs in separate isolate)
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();

      service.on('setAsForeground').listen((_) {
        service.setAsForegroundService();
      });

      service.on('setAsBackground').listen((_) {
        service.setAsBackgroundService();
      });
    }

    service.on('stop').listen((_) {
      service.stopSelf();
    });

    // Handle notification action callbacks from main isolate
    service.on('action').listen((event) {
      if (event != null) {
        _actionStreamController.add(event['action'] as String);
      }
    });

    // Keep service alive
    Timer.periodic(const Duration(seconds: 30), (_) async {
      if (service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: 'Workout Timer',
          content: 'Timer running...',
        );
      }
    });
  }

  /// Send action to background service
  void invokeAction(String action) {
    _service.invoke('action', {'action': action});
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/services/workout_foreground_service.dart`
Expected: No issues (some import warnings expected until integration)

- [ ] **Step 3: Commit**

```bash
git add lib/services/workout_foreground_service.dart
git commit -m "feat: add WorkoutForegroundService with notification actions"
```

---

### Task 3: Wire foreground service to WorkoutTimerPage

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `WorkoutForegroundService` from Task 2, `WorkoutController`
- Produces: Timer page starts/stops foreground service

- [ ] **Step 1: Add import**

In `lib/pages/workout_timer_page.dart`, add import:

```dart
import 'package:my_app/services/workout_foreground_service.dart';
```

- [ ] **Step 2: Start foreground service when workout starts**

Find the start/pause toggle in `_buildHomeLayout()` (around line 1196). The current code is:

```dart
onStartPause: () {
  if (_controller.isRunning) {
    _controller.pause();
    WakelockPlus.disable();
  } else {
    _hasStarted = true;
    _controller.start();
    WakelockPlus.enable();
  }
  setState(() {});
},
```

Change to:

```dart
onStartPause: () {
  if (_controller.isRunning) {
    _controller.pause();
    WakelockPlus.disable();
    WorkoutForegroundService.instance.update(isPaused: true);
  } else {
    _hasStarted = true;
    _controller.start();
    WakelockPlus.enable();
    // Start foreground service
    final phase = _controller.currentPhase;
    WorkoutForegroundService.instance.start(
      workoutName: _controller.config.name ?? 'Workout',
      exerciseName: phase.exerciseName ?? phase.type.label,
      remainingSeconds: _controller.remainingSeconds,
      currentSet: _controller.phaseIndex + 1,
      totalSets: _controller.timeline.length,
      isMusicPlaying: _musicService.player.playing,
    );
  }
  setState(() {});
},
```

- [ ] **Step 3: Update notification on timer tick**

Find the `addListener` callback on `_controller` (search for `_controller.addListener` or the AnimatedBuilder). Add notification update in the listener:

After `_controller.addListener(() { ... })` or inside the existing listener, add:

```dart
// Update foreground notification
if (WorkoutForegroundService.instance.isRunning) {
  final phase = _controller.currentPhase;
  WorkoutForegroundService.instance.update(
    exerciseName: phase.exerciseName ?? phase.type.label,
    remainingSeconds: _controller.remainingSeconds,
    currentSet: _controller.phaseIndex + 1,
    isPaused: !_controller.isRunning,
    isMusicPlaying: _musicService.player.playing,
  );
}
```

- [ ] **Step 4: Stop foreground service on reset/complete**

Find the reset button handler. After `_controller.stop(reset: true); WakelockPlus.disable();`, add:

```dart
WorkoutForegroundService.instance.stop();
```

Also find where workout completion is handled (search for `_didAnnounceCompletion` or completion screen). When workout completes, add:

```dart
WorkoutForegroundService.instance.stop();
```

- [ ] **Step 5: Handle notification actions**

In `initState()` or after `_controller` setup, listen for notification actions:

```dart
WorkoutForegroundService.instance.onAction.listen((action) {
  switch (action) {
    case 'pause':
      if (_controller.isRunning) {
        _controller.pause();
        WakelockPlus.disable();
        WorkoutForegroundService.instance.update(isPaused: true);
      }
    case 'resume':
      if (!_controller.isRunning && _hasStarted) {
        _controller.start();
        WakelockPlus.enable();
        WorkoutForegroundService.instance.update(isPaused: false);
      }
    case 'skip':
      _controller.skipPhase();
      setState(() {});
    case 'stop':
      _controller.stop(reset: true);
      WakelockPlus.disable();
      WorkoutForegroundService.instance.stop();
      setState(() {});
    case 'music_toggle':
    case 'music_stop':
      _musicService.stop();
      setState(() {});
  }
});
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No issues

- [ ] **Step 7: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "feat: wire foreground service to WorkoutTimerPage"
```

---

### Task 4: Wire foreground service to WorkoutBuilderPlayerPage

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `WorkoutForegroundService` from Task 2
- Produces: Builder player starts/stops foreground service

- [ ] **Step 1: Add import**

In `lib/pages/workout_builder_player_page.dart`, add import:

```dart
import 'package:my_app/services/workout_foreground_service.dart';
```

- [ ] **Step 2: Start foreground service when workout starts**

Find the `_start()` method. After the timer is created and `WakelockPlus.enable()` is called, add:

```dart
// Start foreground service
final phase = _timeline[_phaseIndex];
WorkoutForegroundService.instance.start(
  workoutName: _routine?.name ?? 'Workout',
  exerciseName: phase.name,
  remainingSeconds: _remainingSeconds,
  currentSet: _phaseIndex + 1,
  totalSets: _timeline.length,
  isMusicPlaying: _musicService.player.playing,
);
```

- [ ] **Step 3: Update notification on timer tick**

In the `_ticker` callback, after `setState()`, add:

```dart
// Update foreground notification
if (WorkoutForegroundService.instance.isRunning) {
  final phase = _timeline[_phaseIndex];
  WorkoutForegroundService.instance.update(
    exerciseName: phase.name,
    remainingSeconds: _remainingSeconds,
    currentSet: _phaseIndex + 1,
    isPaused: !_isRunning,
    isMusicPlaying: _musicService.player.playing,
  );
}
```

- [ ] **Step 4: Stop foreground service on stop/reset**

In `_stopAndReset()` method, after the ticker is cancelled and state reset, add:

```dart
WorkoutForegroundService.instance.stop();
```

- [ ] **Step 5: Handle notification actions**

In `initState()` or after initialization, listen for notification actions:

```dart
WorkoutForegroundService.instance.onAction.listen((action) {
  switch (action) {
    case 'pause':
      if (_isRunning) {
        _pause();
        WorkoutForegroundService.instance.update(isPaused: true);
      }
    case 'resume':
      if (!_isRunning && !_isComplete && _phaseIndex > 0) {
        _start();
        WorkoutForegroundService.instance.update(isPaused: false);
      }
    case 'skip':
      _skip();
    case 'stop':
      _stopAndReset();
    case 'music_toggle':
    case 'music_stop':
      _musicService.stop();
      setState(() {});
  }
});
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues

- [ ] **Step 7: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat: wire foreground service to WorkoutBuilderPlayerPage"
```

---

### Task 5: Final verification

**Files:** None (read-only)

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze lib/`
Expected: No new issues

- [ ] **Step 2: Build Android release APK**

Run: `flutter build apk --release --target-platform android-arm64`
Expected: Build succeeds

- [ ] **Step 3: Build Windows debug**

Run: `flutter build windows --debug`
Expected: Build succeeds

- [ ] **Step 4: Verify checklist**

Confirm:
- FOREGROUND_SERVICE + WAKE_LOCK permissions in AndroidManifest.xml
- WorkoutForegroundService creates notification with action buttons
- Notification updates every second with exercise/set/time
- Pause/Resume/Skip/Stop/Music actions work from notification
- Timer continues when app is backgrounded
- Notification removed when workout stops
- No analyzer errors
