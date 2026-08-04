# Workout Reminder Settings Inline in Activity Tab Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show workout reminder settings directly at the top of the Activity tab (instead of behind a calendar icon / separate `WorkoutSchedulePage`), with the notification feed below on the same screen.

**Architecture:** Extract the schedule-editor UI and state from `WorkoutSchedulePage` into a self-contained stateful widget `WorkoutScheduleSection` (in `lib/widgets/`), embed it pinned at the top of `NotificationsPage`, render the notification feed below in an `Expanded` `ListView`, then delete `workout_schedule_page.dart` and its calendar-icon entry point. No scheduling behavior changes.

**Tech Stack:** Flutter/Dart, `flutter_local_notifications`, `shared_preferences`, `flutter_test`.

## Global Constraints

- No behavior change to scheduling: weekly reminders still fire at the user's chosen days/time; the once-per-day missed-workout reminder is untouched.
- `WorkoutScheduleSection` owns `SettingsService` and `WorkoutSchedule` state plus the existing save + `ReminderService.scheduleWeeklyNotifications(...)` flow (moved verbatim from `WorkoutSchedulePage`).
- When toggled on from off: send the schedule confirmation notification via `ReminderService.instance.sendScheduleConfirmation(...)` and show the "Workout reminders activated!" snackbar.
- Reuse the existing `_Card` styling (white `0.05` alpha container, `BorderRadius.circular(16)`, `Border.all(color: white 0.08)`) and dark-theme colors (`Color(0xFF2AB7CA)` accents, `Colors.white.withValues(alpha: ...)`).
- The section is always visible at the top of the Activity tab; the notification feed (or "No activity yet" empty state) renders below it.
- Follow existing code style: `const` where possible, no comments unless the surrounding code has them, no new dependencies.

---

### Task 1: Create `WorkoutScheduleSection` widget + widget test

Extract the schedule editor from `WorkoutSchedulePage` into a reusable widget in `lib/widgets/workout_schedule_section.dart`. It renders the enable toggle card always, and the day/time/frequency/summary controls only when enabled. No `Scaffold`/`AppBar` — it is a body-level widget embedded by the Activity page.

**Files:**
- Create: `lib/widgets/workout_schedule_section.dart`
- Test: `test/workout_schedule_section_test.dart` (create)

**Interfaces:**
- Produces: `class WorkoutScheduleSection extends StatefulWidget` with `const WorkoutScheduleSection({super.key})`. No constructor params. Reads/writes the schedule through its own `SettingsService` and `ReminderService.instance`. Renders: `Workout Reminders` toggle card; when enabled, `Days of the Week` day picker, `Time of Day` time picker, `Frequency` slider, and `Schedule Summary`.

- [ ] **Step 1: Write the failing widget test**

Create `test/workout_schedule_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/workout_schedule_section.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('shows the reminders toggle and expands when enabled',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: WorkoutScheduleSection()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workout Reminders'), findsOneWidget);
    expect(find.text('Days of the Week'), findsNothing);

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(find.text('Days of the Week'), findsOneWidget);
    expect(find.text('Time of Day'), findsOneWidget);
    expect(find.text('Frequency'), findsOneWidget);
    expect(find.text('Schedule Summary'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/workout_schedule_section_test.dart`
Expected: FAIL — compilation error "Target of URI doesn't exist" for `package:my_app/widgets/workout_schedule_section.dart`.

- [ ] **Step 3: Write the minimal implementation**

Create `lib/widgets/workout_schedule_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/models/workout_schedule.dart';
import 'package:my_app/services/reminder_service.dart';
import 'package:my_app/services/settings_service.dart';

class WorkoutScheduleSection extends StatefulWidget {
  const WorkoutScheduleSection({super.key});

  @override
  State<WorkoutScheduleSection> createState() => _WorkoutScheduleSectionState();
}

class _WorkoutScheduleSectionState extends State<WorkoutScheduleSection> {
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
    try {
      await ReminderService.instance.scheduleWeeklyNotifications(updated);
    } catch (e) {
      debugPrint('Failed to schedule weekly notifications: $e');
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    final updated = _schedule.copyWith(enabled: value);
    await _updateSchedule(updated);
    if (value && mounted) {
      try {
        await ReminderService.instance.sendScheduleConfirmation(updated);
      } catch (e) {
        debugPrint('Failed to send schedule confirmation: $e');
      }
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
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(color: Color(0xFF2AB7CA))),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        activeThumbColor: const Color(0xFF2AB7CA),
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
              value: _schedule.frequencyPerWeek.clamp(1, maxFreq).toDouble(),
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
    return Material(
      color: Colors.white.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
```

> **Implementation note:** `_Card` uses `Material` (not a `DecoratedBox`) and the frequency slider value is clamped to `[1, maxFreq]`. Both are required to avoid Flutter debug assertions that the extracted page also had: the "ListTile ink splashes may be invisible" assertion for `SwitchListTile` inside a `DecoratedBox`, and the slider crash when the schedule is enabled with no days selected.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/workout_schedule_section_test.dart`
Expected: PASS — toggle card renders, and day/time/frequency controls appear after enabling.

- [ ] **Step 5: Commit**

```bash
git add lib/widgets/workout_schedule_section.dart test/workout_schedule_section_test.dart
git commit -m "feat: extract workout schedule section into reusable widget"
```

---

### Task 1b: Fix the extracted page's debug-mode bugs

Two assertions the old `WorkoutSchedulePage` would hit in debug builds are fixed while extracting:

- `_Card` uses `Material` with a `RoundedRectangleBorder` (same visuals) instead of a `DecoratedBox` wrapping a `ListTile`, satisfying the "ListTile ink splashes may be invisible" debug assertion.
- The frequency `Slider` value is clamped to `[1, maxFreq]` (`_schedule.frequencyPerWeek.clamp(1, maxFreq).toDouble()`), preventing a crash when the schedule is enabled with no days selected.

These are already applied in Task 1's code block; verify with the widget test:

- [ ] **Step 1: Verify the fixes via the widget test**

Run: `flutter test test/workout_schedule_section_test.dart`
Expected: PASS (already covered — the test toggles the switch with an empty `days` list and asserts the controls render without exceptions).

---

### Task 2: Embed the section at the top of the Activity tab

Rewire `NotificationsPage` so the schedule section is pinned at the top and the notification feed scrolls below it, then remove the calendar icon and the `WorkoutSchedulePage` navigation.

**Files:**
- Modify: `lib/pages/notifications_page.dart`
- Modify: `test/widget_test.dart` (add `SharedPreferences.setMockInitialValues({})` in `setUpAll` — the section reads prefs during eager `IndexedStack` build)
- Delete: `lib/pages/workout_schedule_page.dart`

**Interfaces:**
- Consumes: `WorkoutScheduleSection` (Task 1), `NotificationService` (existing).
- Produces: `NotificationsPage` body = `Column` with a scrollable `WorkoutScheduleSection` on top and an `Expanded` feed below (feed or "No activity yet" empty state). No `WorkoutSchedulePage` reference remains anywhere.

- [ ] **Step 1: Update the imports and remove the calendar navigation**

In `lib/pages/notifications_page.dart`:
- Replace `import 'package:my_app/pages/workout_schedule_page.dart';` with `import 'package:my_app/widgets/workout_schedule_section.dart';`
- Delete the `IconButton` (the `actions:` entry that pushes `WorkoutSchedulePage`) from the `AppBar`.

- [ ] **Step 2: Restructure the body**

In `lib/pages/notifications_page.dart`, replace the whole `body:` (currently a `DecoratedBox` whose child is either the empty-state `Center` or the `ListView.separated`) with:

```dart
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: Column(
          children: [
            const SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: WorkoutScheduleSection(),
            ),
            Expanded(
              child: notifications.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 12),
                          Text('No activity yet', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 16)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      itemCount: notifications.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final notif = notifications[index];
                        return _NotificationTile(
                          notification: notif,
                          icon: _iconForType(notif.type),
                          color: _colorForType(notif.type),
                          actionText: _actionText(notif.type),
                          timeAgo: _timeAgo(notif.createdAt),
                          onTap: () => _onNotificationTap(notif),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
```

- [ ] **Step 3: Delete the old page**

Run: `Remove-Item lib\pages\workout_schedule_page.dart`

- [ ] **Step 4: Update widget_test.dart's setUpAll**

`NotificationsPage` is built eagerly inside `MainShellPage`'s `IndexedStack`, so `WorkoutScheduleSection` now reads SharedPreferences at app startup in the widget tests. Add to `test/widget_test.dart` imports:

```dart
import 'package:shared_preferences/shared_preferences.dart';
```

and inside `setUpAll`, after `await setupFirebaseForTesting();`:

```dart
    SharedPreferences.setMockInitialValues({});
```

(Without this, `pumpAndSettle` in `pumpApp` times out because the section's loading spinner never resolves when prefs access throws in the test environment.)

- [ ] **Step 5: Verify no dangling references**

Run: `rg "workout_schedule_page|WorkoutSchedulePage" lib test`
Expected: no matches.

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze`
Expected: no new issues (11 pre-existing `info` lints in unrelated files may remain).

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: PASS — all existing tests plus the new `workout_schedule_section_test.dart`.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: show workout reminder settings inline in Activity tab"
```

---

## Self-Review

**Spec coverage:**
- §1 New reusable widget → Task 1 (`WorkoutScheduleSection` owns settings state, save + `scheduleWeeklyNotifications` flow, renders toggle + day/time/frequency/summary, sends confirmation when toggled on, reuses `_Card` styling).
- §2 Embed at top of Activity tab → Task 2 (pinned `SingleChildScrollView(WorkoutScheduleSection())` above an `Expanded` feed; empty state keeps section at top with "No activity yet" below).
- §3 Remove separate page → Task 2 (calendar icon deleted, `workout_schedule_page.dart` deleted, no dangling references).
- Testing section (analyze clean, existing tests pass, manual checks) → Task 1 test + Task 2 analyze/full-suite; manual items noted for post-build verification.

**Placeholder scan:** no TBD/TODO; every code step has full code; commands have expected output.

**Type consistency:** `WorkoutScheduleSection` is the single shared name used in Tasks 1 and 2; `_settings`, `_schedule`, `_loading` and the `_build*`/`_Card` members match the original `WorkoutSchedulePage` implementation it extracts.

## Final Verification (after all tasks)

- [ ] `flutter analyze` clean of new issues
- [ ] `flutter test` all pass (existing + `workout_schedule_section_test.dart`)
- [ ] Build release APK + AAB so the compiled artifacts include these changes
- [ ] Manual: Activity tab shows reminder settings at top; toggling on expands day/time/frequency controls; schedule confirmation notification appears; notification feed renders below
