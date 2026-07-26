import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.onStartTraining});

  final ValueChanged<WorkoutConfig>? onStartTraining;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final SettingsService _settingsService = SettingsService();
  WorkoutBuilderResumeSession? _resumeSession;

  @override
  void initState() {
    super.initState();
    _refreshResumeSession();
  }

  Future<void> _refreshResumeSession() async {
    final session = await _settingsService.loadWorkoutBuilderResumeSession();
    if (!mounted) {
      return;
    }

    setState(() {
      _resumeSession = session;
    });
  }

  Future<void> _openWorkoutBuilder(BuildContext context) async {
    await Navigator.of(context).pushNamed('/workout-builder');
    await _refreshResumeSession();
  }

  Future<void> _openMyWorkouts(BuildContext context) async {
    await Navigator.of(context).pushNamed('/my-workouts');
    await _refreshResumeSession();
  }

  Future<void> _resumeLastWorkout(BuildContext context) async {
    final session = _resumeSession;
    if (session == null) {
      return;
    }

    await Navigator.of(context).pushNamed(
      '/workout-builder-player',
      arguments: session,
    );
    await _refreshResumeSession();
  }

  Future<void> _openCommunity(BuildContext context) async {
    await Navigator.of(context).pushNamed('/community');
    await _refreshResumeSession();
  }

  Future<void> _openTrainingLauncher(BuildContext context) async {
    final selectedMode = await showModalBottomSheet<_TrainingMode>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _TrainingModeSheet(
          onSelected: (mode) => Navigator.of(sheetContext).pop(mode),
        );
      },
    );

    if (selectedMode == null) {
      return;
    }

    final config = _presetForMode(selectedMode);
    if (widget.onStartTraining != null) {
      widget.onStartTraining!(config);
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).pushNamed('/workout', arguments: config);
    if (!mounted) return;
    await _refreshResumeSession();
  }

  WorkoutConfig _presetForMode(_TrainingMode mode) {
    switch (mode) {
      case _TrainingMode.hiitCardio:
        return const WorkoutConfig(
          sets: 5,
          workSeconds: 40,
          restSeconds: 20,
          warmupSeconds: 180,
          cooldownSeconds: 120,
          intensity: WorkoutIntensity.high,
          program: WorkoutProgram.hiitCardio,
        );
      case _TrainingMode.tabataCardio:
        return const WorkoutConfig(
          sets: 8,
          workSeconds: 20,
          restSeconds: 10,
          warmupSeconds: 180,
          cooldownSeconds: 180,
          intensity: WorkoutIntensity.high,
          finalRestSeconds: 10,
          program: WorkoutProgram.tabataCardio,
        );
      case _TrainingMode.vo2max:
        return const WorkoutConfig(
          sets: 4,
          workSeconds: 240,
          restSeconds: 180,
          warmupSeconds: 600,
          cooldownSeconds: 300,
          intensity: WorkoutIntensity.high,
          finalRestSeconds: 180,
          program: WorkoutProgram.vo2max,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResume = _resumeSession != null;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mods',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Train smarter, not harder.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.0,
                  ),
                  delegate: SliverChildListDelegate([
                    _ModCard(
                      title: 'Quick Start',
                      subtitle: 'Jump right in',
                      icon: Icons.play_circle_fill_rounded,
                      gradient: const [Color(0xFFFF6B8A), Color(0xFFF2A6A6)],
                      onTap: () => _openTrainingLauncher(context),
                    ),
                    _ModCard(
                      title: 'Workout Builder',
                      subtitle: 'Create routines',
                      icon: Icons.bolt_rounded,
                      gradient: const [Color(0xFF4ADE80), Color(0xFF86E3A4)],
                      onTap: () => _openWorkoutBuilder(context),
                    ),
                    _ModCard(
                      title: 'My Workouts',
                      subtitle: 'Your library',
                      icon: Icons.library_books_rounded,
                      gradient: const [Color(0xFF60A5FA), Color(0xFF9BC4FF)],
                      onTap: () => _openMyWorkouts(context),
                    ),
                    _ModCard(
                      title: 'Community',
                      subtitle: 'Share & discover',
                      icon: Icons.public_rounded,
                      gradient: const [Color(0xFFF97316), Color(0xFFF5A97D)],
                      onTap: () => _openCommunity(context),
                    ),
                    if (canResume)
                      _ModCard(
                        title: 'Resume',
                        subtitle: 'Continue last session',
                        icon: Icons.playlist_play_rounded,
                        gradient: const [Color(0xFFFBBF24), Color(0xFFF9C97A)],
                        onTap: () => _resumeLastWorkout(context),
                      ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModCard extends StatelessWidget {
  const _ModCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              gradient[0].withValues(alpha: 0.18),
              gradient[1].withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: gradient[0].withValues(alpha: 0.25),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TrainingMode { hiitCardio, tabataCardio, vo2max }

class _TrainingModeSheet extends StatelessWidget {
  const _TrainingModeSheet({required this.onSelected});

  final ValueChanged<_TrainingMode> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF101A2B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white24),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const Text(
              'Start Training',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pick a mode and jump straight into your next session.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _TrainingModeTile(
              icon: Icons.monitor_heart_rounded,
              title: 'VO2max 4x4 (Quick Start)',
              subtitle: '10 min warm-up, 4x(4:00 push / 3:00 recover), 5-10 min cool-down',
              highlighted: true,
              onTap: () => onSelected(_TrainingMode.vo2max),
            ),
            _TrainingModeTile(
              icon: Icons.flash_on_rounded,
              title: 'HIIT Cardio',
              subtitle: '3 min warm-up, 5x(40s work / 20s rest), 2 min cool-down',
              onTap: () => onSelected(_TrainingMode.hiitCardio),
            ),
            _TrainingModeTile(
              icon: Icons.timer_rounded,
              title: 'Tabata Cardio (10 min)',
              subtitle: '2-3 min warm-up, 8x(20s work / 10s rest), 2-3 min cool-down',
              onTap: () => onSelected(_TrainingMode.tabataCardio),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingModeTile extends StatelessWidget {
  const _TrainingModeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: highlighted
            ? const Color(0xFF2A426E).withValues(alpha: 0.62)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted ? const Color(0xFF9BC4FF) : Colors.white24,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? const Color(0xFF9BC4FF)
                        : const Color(0xFFF2A6A6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: const Color(0xFF18253E), size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (highlighted)
                  const Padding(
                    padding: EdgeInsets.only(left: 8),
                    child: Text(
                      'Focus',
                      style: TextStyle(
                        color: Color(0xFF9BC4FF),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
