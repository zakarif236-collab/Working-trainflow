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
