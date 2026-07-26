# Weekly Workout Notification Schedule - Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let users set a weekly workout reminder schedule (days, time, frequency) in the Activity section, with automatic local notifications and an immediate confirmation.

**Architecture:** Add a `WorkoutSchedule` model persisted via SharedPreferences. Extend `ReminderService` to schedule weekly notifications using `flutter_local_notifications` with `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`. Add a schedule configuration page accessible from the Activity tab.

**Tech Stack:** flutter_local_notifications, timezone, SharedPreferences, Material 3 dark theme.

## Global Constraints

- Material 3 dark theme with gradient backgrounds (`Color(0xFF141B2D)`, `Color(0xFF0A1020)`, `Color(0xFF1A2439)`)
- SharedPreferences for all local storage
- `flutter_local_notifications` for scheduling
- No external state management (StatefulWidget + ChangeNotifier only)
- All new pages must match existing dark gradient style
- Notification channel: reuse existing `workout_reminders` channel

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/models/workout_schedule.dart` | `WorkoutSchedule` data model (days, time, frequency, enabled) |
| `lib/services/workout_schedule_service.dart` | Persistence + scheduling logic |
| `lib/pages/workout_schedule_page.dart` | UI for configuring the weekly schedule |
| `lib/pages/notifications_page.dart` | Add button to access schedule page |
| `lib/services/reminder_service.dart` | Add `scheduleWeeklyNotifications()` and `cancelWeeklyNotifications()` |
| `lib/services/settings_service.dart` | Add schedule load/save methods |

---

### Task 1: WorkoutSchedule Model

**Files:**
- Create: `lib/models/workout_schedule.dart`

**Interfaces:**
- Produces: `WorkoutSchedule` class with `toJson()`, `fromJson()`, `copyWith()`

- [ ] **Step 1: Create the model file**

```dart
import 'dart:convert';

class WorkoutSchedule {
  const WorkoutSchedule({
    this.enabled = false,
    this.days = const [],       // 1=Monday..7=Sunday (DateTime weekday values)
    this.hour = 8,
    this.minute = 0,
    this.frequencyPerWeek = 3,  // how many of the selected days to actually notify
  });

  final bool enabled;
  final List<int> days;
  final int hour;
  final int minute;
  final int frequencyPerWeek;

  WorkoutSchedule copyWith({
    bool? enabled,
    List<int>? days,
    int? hour,
    int? minute,
    int? frequencyPerWeek,
  }) {
    return WorkoutSchedule(
      enabled: enabled ?? this.enabled,
      days: days ?? this.days,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      frequencyPerWeek: frequencyPerWeek ?? this.frequencyPerWeek,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'days': days,
    'hour': hour,
    'minute': minute,
    'frequencyPerWeek': frequencyPerWeek,
  };

  factory WorkoutSchedule.fromJson(Map<String, dynamic> json) {
    return WorkoutSchedule(
      enabled: json['enabled'] as bool? ?? false,
      days: (json['days'] as List<dynamic>?)?.cast<int>() ?? [],
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
      frequencyPerWeek: json['frequencyPerWeek'] as int? ?? 3,
    );
  }

  String encode() => jsonEncode(toJson());

  factory WorkoutSchedule.decode(String source) {
    return WorkoutSchedule.fromJson(jsonDecode(source) as Map<String, dynamic>);
  }

  String get timeLabel {
    final h = hour > 12 ? hour - 12 : hour == 0 ? 12 : hour;
    final ampm = hour >= 12 ? 'PM' : 'AM';
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }

  static const dayNames = {
    1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu',
    5: 'Fri', 6: 'Sat', 7: 'Sun',
  };

  static const fullDayNames = {
    1: 'Monday', 2: 'Tuesday', 3: 'Wednesday', 4: 'Thursday',
    5: 'Friday', 6: 'Saturday', 7: 'Sunday',
  };
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/models/workout_schedule.dart`
Expected: No errors (info-level lints OK)

- [ ] **Step 3: Commit**

```bash
git add lib/models/workout_schedule.dart
git commit -m "feat: add WorkoutSchedule model for weekly notification schedule"
```

---

### Task 2: Schedule Persistence in SettingsService

**Files:**
- Modify: `lib/services/settings_service.dart` (add 3 methods at end of class)

**Interfaces:**
- Consumes: `WorkoutSchedule` from Task 1
- Produces: `loadWorkoutSchedule()`, `saveWorkoutSchedule(WorkoutSchedule)`, `clearWorkoutSchedule()`

- [ ] **Step 1: Add import**

At top of `settings_service.dart`, add:
```dart
import 'package:my_app/models/workout_schedule.dart';
```

- [ ] **Step 2: Add schedule methods**

Add these methods inside the `SettingsService` class (before the closing brace):

```dart
  // --- Workout Schedule ---

  static const _scheduleKey = 'workout_schedule';

  Future<WorkoutSchedule> loadWorkoutSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduleKey);
    if (raw == null || raw.isEmpty) {
      return const WorkoutSchedule();
    }
    try {
      return WorkoutSchedule.decode(raw);
    } catch (_) {
      return const WorkoutSchedule();
    }
  }

  Future<void> saveWorkoutSchedule(WorkoutSchedule schedule) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduleKey, schedule.encode());
  }

  Future<void> clearWorkoutSchedule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_scheduleKey);
  }
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/services/settings_service.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add workout schedule persistence to SettingsService"
```

---

### Task 3: Weekly Notification Scheduling in ReminderService

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

---

### Task 4: Workout Schedule Configuration Page

**Files:**
- Create: `lib/pages/workout_schedule_page.dart`

**Interfaces:**
- Consumes: `WorkoutSchedule` from Task 1, `SettingsService` from Task 2, `ReminderService` from Task 3
- Produces: navigable page widget

- [ ] **Step 1: Create the page**

```dart
import 'package:flutter/material.dart';
import 'package:my_app/models/workout_schedule.dart';
import 'package:my_app/services/reminder_service.dart';
import 'package:my_app/services/settings_service.dart';

class WorkoutSchedulePage extends StatefulWidget {
  const WorkoutSchedulePage({super.key});

  @override
  State<WorkoutSchedulePage> createState() => _WorkoutSchedulePageState();
}

class _WorkoutSchedulePageState extends State<WorkoutSchedulePage> {
  final SettingsService _settings = SettingsService();
  WorkoutSchedule _schedule = const WorkoutSchedule();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedule();
  }

  Future<void> _loadSchedule() async {
    final loaded = await _settings.loadWorkoutSchedule();
    if (!mounted) return;
    setState(() {
      _schedule = loaded;
      _loading = false;
    });
  }

  Future<void> _toggleDay(int day) async {
    final days = List<int>.from(_schedule.days);
    if (days.contains(day)) {
      days.remove(day);
    } else {
      days.add(day);
    }
    // Clamp frequency to not exceed selected days
    final freq = _schedule.frequencyPerWeek.clamp(1, days.length.clamp(1, 7));
    await _updateSchedule(_schedule.copyWith(days: days, frequencyPerWeek: freq));
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _schedule.hour, minute: _schedule.minute),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: const Color(0xFF1A2235),
              hourMinuteColor: Colors.white.withValues(alpha: 0.08),
              dayPeriodColor: Colors.white.withValues(alpha: 0.08),
              dayPeriodTextColor: Colors.white70,
              hourMinuteTextColor: Colors.white,
              dialBackgroundColor: Colors.white.withValues(alpha: 0.06),
              dialHandColor: const Color(0xFF2AB7CA),
              dialTextColor: Colors.white,
              entryModeIconColor: const Color(0xFF2AB7CA),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      await _updateSchedule(_schedule.copyWith(hour: picked.hour, minute: picked.minute));
    }
  }

  Future<void> _updateSchedule(WorkoutSchedule updated) async {
    setState(() => _schedule = updated);
    await _settings.saveWorkoutSchedule(updated);
    await ReminderService.instance.scheduleWeeklyNotifications(updated);
  }

  Future<void> _toggleEnabled(bool value) async {
    final updated = _schedule.copyWith(enabled: value);
    await _updateSchedule(updated);
    if (value && mounted) {
      await ReminderService.instance.sendScheduleConfirmation(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workout reminders activated!'),
            backgroundColor: Color(0xFF2AB7CA),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Workout Schedule'), backgroundColor: const Color(0xFF101A2B)),
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2AB7CA))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Workout Schedule'), backgroundColor: const Color(0xFF101A2B)),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildEnableToggle(),
            const SizedBox(height: 20),
            if (_schedule.enabled) ...[
              _buildSectionTitle('Days of the Week'),
              const SizedBox(height: 10),
              _buildDayPicker(),
              const SizedBox(height: 24),
              _buildSectionTitle('Time of Day'),
              const SizedBox(height: 10),
              _buildTimePicker(),
              const SizedBox(height: 24),
              _buildSectionTitle('Frequency'),
              const SizedBox(height: 10),
              _buildFrequencyPicker(),
              const SizedBox(height: 32),
              _buildSummary(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnableToggle() {
    return _Card(
      child: SwitchListTile(
        title: Text(
          'Workout Reminders',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          _schedule.enabled ? 'Reminders are active' : 'Enable to get reminded',
          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 13),
        ),
        value: _schedule.enabled,
        onChanged: _toggleEnabled,
        activeColor: const Color(0xFF2AB7CA),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
    );
  }

  Widget _buildDayPicker() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [1, 2, 3, 4, 5, 6, 7].map((day) {
        final selected = _schedule.days.contains(day);
        return GestureDetector(
          onTap: () => _toggleDay(day),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF2AB7CA).withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? const Color(0xFF2AB7CA)
                    : Colors.white.withValues(alpha: 0.1),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Center(
              child: Text(
                WorkoutSchedule.dayNames[day]!,
                style: TextStyle(
                  color: selected ? const Color(0xFF2AB7CA) : Colors.white.withValues(alpha: 0.5),
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker() {
    return GestureDetector(
      onTap: _pickTime,
      child: _Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(Icons.access_time_rounded, color: const Color(0xFF2AB7CA), size: 22),
              const SizedBox(width: 12),
              Text(
                _schedule.timeLabel,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: Colors.white.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFrequencyPicker() {
    final maxFreq = _schedule.days.length.clamp(1, 7);
    return _Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remind me ${_schedule.frequencyPerWeek}x per week',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _schedule.frequencyPerWeek.toDouble(),
              min: 1,
              max: maxFreq.toDouble(),
              divisions: maxFreq > 1 ? maxFreq - 1 : 1,
              label: '${_schedule.frequencyPerWeek}',
              activeColor: const Color(0xFF2AB7CA),
              inactiveColor: Colors.white.withValues(alpha: 0.1),
              onChanged: (v) {
                _updateSchedule(_schedule.copyWith(frequencyPerWeek: v.round()));
              },
            ),
            Text(
              'Pick ${_schedule.frequencyPerWeek} of ${_schedule.days.length} selected days',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_schedule.days.isEmpty) return const SizedBox.shrink();

    final sortedDays = List<int>.from(_schedule.days)..sort();
    final dayLabels = sortedDays
        .take(_schedule.frequencyPerWeek)
        .map((d) => WorkoutSchedule.fullDayNames[d] ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return _Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Schedule Summary',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, color: const Color(0xFF2AB7CA), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dayLabels,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time_rounded, color: const Color(0xFF2AB7CA), size: 18),
                const SizedBox(width: 8),
                Text(
                  _schedule.timeLabel,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/pages/workout_schedule_page.dart`
Expected: No errors

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout_schedule_page.dart
git commit -m "feat: add workout schedule configuration page"
```

---

### Task 5: Add Schedule Access from Activity Page

**Files:**
- Modify: `lib/pages/notifications_page.dart` (add schedule button to AppBar)

**Interfaces:**
- Consumes: `WorkoutSchedulePage` from Task 4

- [ ] **Step 1: Add import**

At top of `notifications_page.dart`, add:
```dart
import 'package:my_app/pages/workout_schedule_page.dart';
```

- [ ] **Step 2: Add schedule icon button to AppBar actions**

In the `AppBar.actions` list, add a schedule button before the existing `Mark all read` button:

```dart
        actions: [
          IconButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const WorkoutSchedulePage()),
              );
            },
            icon: const Icon(Icons.calendar_week_rounded, size: 22),
            tooltip: 'Workout schedule',
            color: Colors.white.withValues(alpha: 0.6),
          ),
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () => _notifService.markAllAsRead(),
              child: const Text('Mark all read'),
            ),
        ],
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/pages/notifications_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/pages/notifications_page.dart
git commit -m "feat: add workout schedule access from Activity page"
```

---

### Task 6: Wire Up Schedule on App Start

**Files:**
- Modify: `lib/pages/main_shell_page.dart` (schedule weekly notifications on init alongside daily motivation)

**Interfaces:**
- Consumes: `ReminderService` from Task 3, `SettingsService` from Task 2, `WorkoutSchedule` from Task 1

- [ ] **Step 1: Add imports**

At top of `main_shell_page.dart`, add:
```dart
import 'package:my_app/models/workout_schedule.dart';
import 'package:my_app/services/settings_service.dart';
```

- [ ] **Step 2: Schedule weekly notifications on init**

In `_scheduleDailyNotification()` (called from `initState`), add after the existing `ReminderService.instance.scheduleDailyMotivation(...)` call:

```dart
    // Re-schedule weekly workout notifications from saved preferences
    try {
      final schedule = await SettingsService().loadWorkoutSchedule();
      if (schedule.enabled && schedule.days.isNotEmpty) {
        await ReminderService.instance.scheduleWeeklyNotifications(schedule);
      }
    } catch (_) {}
```

- [ ] **Step 3: Verify no analysis errors**

Run: `flutter analyze lib/pages/main_shell_page.dart`
Expected: No errors

- [ ] **Step 4: Commit**

```bash
git add lib/pages/main_shell_page.dart
git commit -m "feat: wire up weekly notification scheduling on app start"
```

---

### Task 7: Build and Verify

- [ ] **Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No new errors

- [ ] **Step 2: Build release APK**

Run: `flutter build apk --release`
Expected: Build succeeds

- [ ] **Step 3: Final commit if any fixups needed**
