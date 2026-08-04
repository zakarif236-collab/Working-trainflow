import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

@pragma('vm:entry-point')
class WorkoutForegroundService {
  WorkoutForegroundService._();

  static final WorkoutForegroundService instance = WorkoutForegroundService._();

  static const _channelId = 'workout_foreground';
  static const _channelName = 'Workout Timer';
  static const _notificationId = 888;

  /// Companion interactive notification shown while the service is promoted to
  /// foreground. The plugin's own foreground notification cannot carry action
  /// buttons, so this one provides the Pause/Resume and Stop controls.
  static const _actionNotificationId = 889;
  static const _pauseActionId = 'workout.pause';
  static const _stopActionId = 'workout.stop';

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final _actionStreamController = StreamController<String>.broadcast();
  Stream<String> get onAction => _actionStreamController.stream;

  bool _isRunning = false;
  bool get isRunning => _isRunning;

  /// True only while the companion notification is visible (i.e. the app is
  /// backgrounded/locked). Guards `_showActionNotification` in [update] so no
  /// notification is posted while the user is inside the app.
  bool _isForegrounded = false;

  bool _actionForwarderAttached = false;

  // Current workout state for notification
  String _workoutName = 'Workout';
  String _exerciseName = '';
  int _remainingSeconds = 0;
  int _currentSet = 1;
  int _totalSets = 3;
  bool _isPaused = false;
  bool _isMusicPlaying = false;
  String _lastActionContent = '';

  /// Cancel any stale notification (call on app launch to clean up leftovers)
  static Future<void> cancelStaleNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await plugin.initialize(initSettings);
    await plugin.cancel(_notificationId);
  }

  /// Start the background service (keeps timer alive in background).
  /// No notification is shown until [promoteToForeground] is called.
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
    _isForegrounded = false;
    _lastActionContent = '';

    await _initLocalNotifications();
    await _createNotificationChannel();
    await _service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: false,
        notificationChannelId: _channelId,
        initialNotificationTitle: _workoutName,
        initialNotificationContent: _exerciseName,
        foregroundServiceNotificationId: _notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
      ),
    );

    await _service.startService();
    _isRunning = true;

    // Forward any 'action' events the background isolate bounces back to the
    // main isolate so the UI can react to notification actions. Attached once,
    // after configure() so the platform event channel is live.
    if (!_actionForwarderAttached) {
      _actionForwarderAttached = true;
      try {
        _service.on('action').listen((data) {
          if (data != null && data['action'] is String) {
            _actionStreamController.add(data['action'] as String);
          }
        });
      } catch (_) {
        // Unsupported platform (e.g. tests/desktop) — no action forwarding.
      }
    }
  }

  /// Promote to foreground — shows the notification (call when app goes to background).
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _isForegrounded = true;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
    if (Platform.isAndroid) {
      _lastActionContent = '';
      await _showActionNotification();
    }
  }

  /// Demote to background — hides the notification (call when app returns to foreground).
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _isForegrounded = false;
    _service.invoke('setAsBackground');
    if (Platform.isAndroid) {
      await _localNotifications.cancel(_actionNotificationId);
    }
  }

  /// Stop the service and remove notification
  Future<void> stop() async {
    if (!_isRunning) return;

    _service.invoke('stop');
    _isRunning = false;
    _isForegrounded = false;

    if (Platform.isAndroid) {
      await _localNotifications.cancel(_actionNotificationId);
    }
    await _localNotifications.cancel(_notificationId);
  }

  /// Update workout state
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
      _updateForegroundNotificationInfo();
      if (Platform.isAndroid && _isForegrounded) {
        await _showActionNotification();
      }
    }
  }

  void _updateForegroundNotificationInfo() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final setStr = 'Set $_currentSet/$_totalSets';
    final stateStr = '$_exerciseName • $setStr • $timeStr'
        '${_isMusicPlaying ? ' • Music' : ''}'
        '${_isPaused ? ' • Paused' : ''}';
    _service.invoke('setNotificationInfo', {
      'title': _workoutName,
      'content': stateStr,
    });
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationAction,
    );
  }

  /// Show (or update) the companion interactive notification with action
  /// buttons. Deduped by content so we don't re-post on every tick.
  Future<void> _showActionNotification() async {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final content = '$_exerciseName • Set $_currentSet/$_totalSets • $timeStr'
        '${_isMusicPlaying ? ' • Music' : ''}'
        '${_isPaused ? ' • Paused' : ''}';
    if (content == _lastActionContent) return;
    _lastActionContent = content;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Shows workout progress and controls',
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
        actions: [
          AndroidNotificationAction(
            _pauseActionId,
            _isPaused ? 'Resume' : 'Pause',
          ),
          AndroidNotificationAction(_stopActionId, 'Stop'),
        ],
      ),
    );
    await _localNotifications.show(
      _actionNotificationId,
      _workoutName,
      content,
      details,
      payload: 'workout_controls',
    );
  }

  /// Handle taps on the companion notification's action buttons.
  void _onNotificationAction(NotificationResponse response) {
    if (response.payload != 'workout_controls') return;
    switch (response.actionId) {
      case _pauseActionId:
        _actionStreamController.add(_isPaused ? 'resume' : 'pause');
      case _stopActionId:
        _actionStreamController.add('stop');
    }
  }

  Future<void> _createNotificationChannel() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Shows workout progress and controls',
        importance: Importance.high,
      ),
    );
  }

  /// Background service entry point (runs in separate isolate)
  @pragma('vm:entry-point')
  static void _onStart(ServiceInstance service) async {
    DartPluginRegistrant.ensureInitialized();

    if (service is AndroidServiceInstance) {
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

    // Forward notification info updates from main isolate to native
    service.on('setNotificationInfo').listen((data) {
      if (data != null && service is AndroidServiceInstance) {
        service.setForegroundNotificationInfo(
          title: data['title'] as String? ?? 'Workout Timer',
          content: data['content'] as String? ?? 'Timer running...',
        );
      }
    });

    // Handle notification action callbacks from main isolate
    service.on('action').listen((event) {
      if (event != null) {
        // Bounce back to the main isolate, which owns the UI-facing stream.
        service.invoke('action', event);
      }
    });
  }

  /// Send action to background service
  void invokeAction(String action) {
    _service.invoke('action', {'action': action});
  }
}
