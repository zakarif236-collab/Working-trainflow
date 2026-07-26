import 'dart:math';

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

  static const _dailyNotificationId = 7700;
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
    await _requestPermissions();
    _initialized = true;
  }

  Future<void> scheduleDailyMotivation(SettingsService settingsService) async {
    await initialize();

    final insights = await settingsService.loadInsights();
    final streak = insights.currentStreakDays;
    final message = _pickMessage(streak);

    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'workout_reminders',
        'Workout Reminders',
        channelDescription: 'Daily motivation to keep your training streak alive',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.zonedSchedule(
      _dailyNotificationId,
      'Time to train',
      message,
      scheduled,
      details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> maybeSendDailyWorkoutReminder(SettingsService settingsService) async {
    await initialize();

    final shouldSend = await settingsService.shouldSendMissedWorkoutReminder();
    if (!shouldSend) {
      return;
    }

    final insights = await settingsService.loadInsights();
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

    await _notifications.show(
      9001,
      'Daily workout reminder',
      message,
      details,
    );

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

  Future<void> scheduleWeeklyNotifications(WorkoutSchedule schedule) async {
    await initialize();
    await cancelWeeklyNotifications();

    if (!schedule.enabled || schedule.days.isEmpty) return;

    final selectedDays = List<int>.from(schedule.days)..sort();
    final daysToSchedule = selectedDays.take(schedule.frequencyPerWeek).toList();

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

      await _notifications.zonedSchedule(
        id,
        'Workout Reminder',
        messages[rng.nextInt(messages.length)],
        scheduled,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
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

    await _notifications.show(
      9002,
      'Schedule saved!',
      'Reminders set for $dayNames at ${schedule.timeLabel}.',
      details,
    );
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
