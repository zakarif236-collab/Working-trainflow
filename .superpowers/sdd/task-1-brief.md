# Task 1: WorkoutSchedule Model

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
