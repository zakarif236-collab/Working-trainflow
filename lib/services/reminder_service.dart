import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:my_app/models/workout_schedule.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;

class ReminderService {
  ReminderService._();

  static final ReminderService instance = ReminderService._();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _weeklyNotificationIdBase = 8800;
  static const _messagesNoStreak = [
    "New day, new PR waiting to happen. Lace up and let's go!",
    "Your future self will thank you for showing up today.",
    "The only bad workout is the one you didn't do. Let's move!",
    "Today's effort is tomorrow's result. Time to train!",
    "You didn't come this far to only come this far. Get after it!",
  ];

  static const _messagesShortStreak = [
    "You're building momentum — don't let it slip! Time to train.",
    "2 days in? That's not luck, that's discipline. Keep going!",
    "Your body is waking up. One more session and you'll feel unstoppable.",
    "Consistency is king. You're proving you have it. Let's go!",
  ];

  static const _messagesMidStreak = [
    "A week of showing up. You're officially dangerous. Keep pushing!",
    "You're in the zone now. Missing today would be a crime.",
    "That fire in your chest? That's habit forming. Feed it.",
    "Strong days stack up. You're building something real. Don't stop.",
  ];

  static const _messagesLongStreak = [
    "Absolute machine. You don't skip days anymore — days skip you.",
    "Your consistency is elite. Time to raise the bar even higher.",
    "Champions are built in moments like this. Show up and dominate.",
    "You've earned that body. Now go earn the next level.",
  ];

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();
    await _setLocalLocation();

    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );

      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notifications.initialize(initSettings);
    } catch (e) {
      debugPrint('ReminderService: notification plugin init failed: $e');
    }

    try {
      await _requestPermissions();
    } catch (e) {
      debugPrint('ReminderService: notification permission request failed: $e');
    }
    _initialized = true;
  }

  Future<void> maybeSendDailyWorkoutReminder(SettingsService settingsService) async {
    await initialize();

    final shouldSend = await settingsService.shouldSendMissedWorkoutReminder();
    if (!shouldSend) {
      return;
    }

    final schedule = await settingsService.loadWorkoutSchedule();
    if (!schedule.enabled) {
      return;
    }

    final insights = await settingsService.loadInsights();
    final lastWorkoutAt = insights.lastWorkoutAt;
    if (lastWorkoutAt != null && _isSameLocalDay(lastWorkoutAt, DateTime.now())) {
      return;
    }

    final streak = insights.currentStreakDays;
    final message = _pickMessage(streak);

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        channelDescription: 'Helps users stay consistent with workout streaks',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notifications.show(
        9001,
        'Daily workout reminder',
        message,
        details,
      );
    } catch (e) {
      debugPrint('ReminderService: failed to show daily reminder: $e');
    }

    await settingsService.markReminderSent();
  }

  Future<void> maybeSendMissedWorkoutReminder(SettingsService settingsService) {
    return maybeSendDailyWorkoutReminder(settingsService);
  }

  String _pickMessage(int streak) {
    final rng = Random();
    List<String> pool;
    if (streak >= 8) {
      pool = _messagesLongStreak;
    } else if (streak >= 4) {
      pool = _messagesMidStreak;
    } else if (streak >= 1) {
      pool = _messagesShortStreak;
    } else {
      pool = _messagesNoStreak;
    }
    return pool[rng.nextInt(pool.length)];
  }

  bool _isSameLocalDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> scheduleWeeklyNotifications(WorkoutSchedule schedule) async {
    await initialize();

    try {
      await cancelWeeklyNotifications();
    } catch (e) {
      debugPrint('ReminderService: failed to clear previous weekly reminders: $e');
    }

    if (!schedule.enabled || schedule.days.isEmpty) {
      debugPrint('ReminderService: weekly reminders cleared (schedule disabled or no days selected)');
      return;
    }

    final selectedDays = List<int>.from(schedule.days)..sort();
    final daysToSchedule = selectedDays.take(schedule.frequencyPerWeek).toList();
    debugPrint(
      'ReminderService: scheduling weekly reminders — days=$daysToSchedule '
      'time=${schedule.hour}:${schedule.minute}',
    );

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        channelDescription: 'Weekly workout reminders on your chosen days',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    final messages = [
      'Time for your workout! You chose this — now show up.',
      "It's workout day! Let's make it count.",
      'Your body is ready. Time to train!',
      "Reminder: you committed to this. Let's go!",
      "Workout time! You're stronger than yesterday.",
    ];
    final rng = Random();

    for (final day in daysToSchedule) {
      final id = _weeklyNotificationIdBase + day;
      final now = tz.TZDateTime.now(tz.local);

      var scheduled = tz.TZDateTime(
        tz.local, now.year, now.month, now.day,
        schedule.hour, schedule.minute,
      );

      // Find the next occurrence of this weekday
      while (scheduled.weekday != day || scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      try {
        await _notifications.zonedSchedule(
          id,
          'Workout Reminder',
          messages[rng.nextInt(messages.length)],
          scheduled,
          details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
        debugPrint('ReminderService: scheduled weekly reminder id=$id weekday=$day at $scheduled');
      } catch (e) {
        debugPrint('ReminderService: failed to schedule weekly reminder for day $day: $e');
      }
    }
  }

  Future<void> cancelWeeklyNotifications() async {
    await initialize();
    for (var day = 1; day <= 7; day++) {
      await _notifications.cancel(_weeklyNotificationIdBase + day);
    }
  }

  Future<void> sendScheduleConfirmation(WorkoutSchedule schedule) async {
    await initialize();

    final dayNames = schedule.days
        .map((d) => WorkoutSchedule.dayNames[d] ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        channelDescription: 'Workout schedule confirmation',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    try {
      await _notifications.show(
        9002,
        'Schedule saved!',
        'Reminders set for $dayNames at ${schedule.timeLabel}.',
        details,
      );
    } catch (e) {
      debugPrint('ReminderService: failed to show schedule confirmation: $e');
    }
  }

  Future<void> _setLocalLocation() async {
    try {
      final localTz = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localTz.identifier));
    } catch (e) {
      debugPrint('Failed to set local timezone: $e');
    }
  }

  Future<void> _requestPermissions() async {
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _notifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _notifications.resolvePlatformSpecificImplementation<
        MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }
}
