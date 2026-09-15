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

  /// Title shown for the current phase. Kept separately so a workout-name-only
  /// change (e.g. localization) can be detected without re-posting on ticks.
  String _lastActionTitle = '';

  /// Cancel any stale notification (call on app launch to clean up leftovers)
  static Future<void> cancelStaleNotifications() async {
    final plugin = FlutterLocalNotificationsPlugin();
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await plugin.initialize(initSettings);
    await plugin.cancel(_notificationId);
    await plugin.cancel(_actionNotificationId);
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
      _lastActionTitle = '';
      await _showActionNotification();
    }
  }

  /// Push the authoritative remaining seconds without forcing a re-post of the
  /// stable body. Call this after the timer reconciles wall-clock time (e.g. on
  /// resume) so the notification's chronometer matches the on-screen countdown.
  void syncTime(int remainingSeconds) {
    _remainingSeconds = remainingSeconds;
    if (!_isForegrounded) return;
    // Re-post so the chronometer's base timestamp is refreshed; the stable body
    // is unchanged, so this does not alert or duplicate.
    _lastActionContent = '';
    _lastActionTitle = '';
    unawaited(_showActionNotification());
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

  /// Push the *stable* state to the plugin's own foreground notification (888).
  /// Intentionally omits the countdown: 888 and the companion (889) must not
  /// both render a time, or they disagree whenever the isolate is throttled.
  void _updateForegroundNotificationInfo() {
    _service.invoke('setNotificationInfo', {
      'title': _workoutName,
      'content': _stableActionContent,
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

  /// The stable (non-ticking) body line for the companion notification.
  /// Excludes the countdown so the dedupe key does not change every second —
  /// the live time is rendered by the system via `usesChronometer`.
  String get _stableActionContent =>
      '$_exerciseName${_setSegment()}'
      '${_isMusicPlaying ? ' • Music' : ''}'
      '${_isPaused ? ' • Paused' : ''}';

  String _setSegment() {
    if (_totalSets <= 0 || _currentSet <= 0) return '';
    return ' • Set $_currentSet/$_totalSets';
  }

  /// Show (or update) the companion interactive notification with action
  /// buttons. Re-posted only when the *stable* body changes (phase, set, pause,
  /// music) — never on the 1 Hz countdown, which the system updates in place.
  Future<void> _showActionNotification() async {
    final content = _stableActionContent;
    if (content == _lastActionContent && _workoutName == _lastActionTitle) {
      return;
    }
    _lastActionContent = content;
    _lastActionTitle = _workoutName;

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Shows workout progress and controls',
        importance: Importance.high,
        priority: Priority.high,
        onlyAlertOnce: true,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        usesChronometer: _usesChronometer,
        chronometerCountDown: _usesChronometer,
        when: _chronometerBaseMillis,
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

  /// A running countdown is only meaningful while the workout is actually
  /// ticking; pausing freezes it at the current remaining seconds.
  bool get _usesChronometer => !_isPaused && _remainingSeconds > 0;

  /// The chronometer is a countdown to (now + remaining). Recomputed on every
  /// post so the shade and the timer cannot drift apart.
  int get _chronometerBaseMillis =>
      DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

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
