import 'dart:async';
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

  final FlutterBackgroundService _service = FlutterBackgroundService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  static final _actionStreamController = StreamController<String>.broadcast();
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
  }

  /// Promote to foreground — shows the notification (call when app goes to background).
  Future<void> promoteToForeground() async {
    if (!_isRunning) return;
    _updateForegroundNotificationInfo();
    _service.invoke('setAsForeground');
  }

  /// Demote to background — hides the notification (call when app returns to foreground).
  Future<void> demoteToBackground() async {
    if (!_isRunning) return;
    _service.invoke('setAsBackground');
  }

  /// Stop the service and remove notification
  Future<void> stop() async {
    if (!_isRunning) return;

    _service.invoke('stop');
    _isRunning = false;

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
    }
  }

  void _updateForegroundNotificationInfo() {
    final minutes = _remainingSeconds ~/ 60;
    final seconds = _remainingSeconds % 60;
    final timeStr = '$minutes:${seconds.toString().padLeft(2, '0')}';
    final setStr = 'Set $_currentSet/$_totalSets';
    _service.invoke('setNotificationInfo', {
      'title': _workoutName,
      'content': '$_exerciseName • $setStr • $timeStr',
    });
  }

  /// Initialize local notifications
  Future<void> _initLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidSettings);
    await _localNotifications.initialize(initSettings);
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
        _actionStreamController.add(event['action'] as String);
      }
    });
  }

  /// Send action to background service
  void invokeAction(String action) {
    _service.invoke('action', {'action': action});
  }
}
