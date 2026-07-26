# Task 3: Weekly Notification Scheduling in ReminderService

**Files:**
- Modify: `lib/services/reminder_service.dart` (add 2 methods + 1 helper + 1 constant)

**Interfaces:**
- Consumes: `WorkoutSchedule` from Task 1
- Produces: `scheduleWeeklyNotifications(WorkoutSchedule)`, `cancelWeeklyNotifications()`

- [ ] **Step 1: Add import**

At top of `reminder_service.dart`, add:
```dart
import 'package:my_app/models/workout_schedule.dart';
```

- [ ] **Step 2: Add weekly notification IDs constant**

After the `_dailyNotificationId` constant, add:
```dart
  static const _weeklyNotificationIdBase = 8800;
```

- [ ] **Step 3: Add scheduleWeeklyNotifications method**

Add inside the `ReminderService` class:

```dart
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
```

- [ ] **Step 4: Add cancelWeeklyNotifications method**

Add inside the `ReminderService` class:

```dart
  Future<void> cancelWeeklyNotifications() async {
    await initialize();
    for (var day = 1; day <= 7; day++) {
      await _notifications.cancel(_weeklyNotificationIdBase + day);
    }
  }
```

- [ ] **Step 5: Add schedule confirmation method**

Add inside the `ReminderService` class:

```dart
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
```

- [ ] **Step 6: Verify no analysis errors**

Run: `flutter analyze lib/services/reminder_service.dart`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add lib/services/reminder_service.dart
git commit -m "feat: add weekly notification scheduling to ReminderService"
```
