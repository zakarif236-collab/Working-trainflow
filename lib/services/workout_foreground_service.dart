import 'dart:async';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

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
      iosConfiguration: IosConfiguration(
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
