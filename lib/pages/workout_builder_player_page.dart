import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/cue_service.dart';
import 'package:my_app/services/settings_service.dart';

import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/workout_timeline.dart';

enum _BuilderPhaseType { work, rest, complete }

class _BuilderPhase {
  const _BuilderPhase({
    required this.type,
    required this.durationSeconds,
    required this.exerciseIndex,
    required this.exercise,
    required this.label,
  });

  final _BuilderPhaseType type;
  final int durationSeconds;
  final int exerciseIndex;
  final WorkoutBuilderExercise exercise;
  final String label;
}

class WorkoutBuilderPlayerPage extends StatefulWidget {
  const WorkoutBuilderPlayerPage({super.key});

  @override
  State<WorkoutBuilderPlayerPage> createState() => _WorkoutBuilderPlayerPageState();
}

class _WorkoutBuilderPlayerPageState extends State<WorkoutBuilderPlayerPage> {
  final CueService _cueService = CueService();
  final SettingsService _settingsService = SettingsService();

  WorkoutBuilderRoutine? _routine;
  List<_BuilderPhase> _timeline = const [];
  Timer? _ticker;

  int _phaseIndex = 0;
  int _remainingSeconds = 0;
  bool _isRunning = false;
  bool _didInit = false;

  bool _voiceCueEnabled = true;
  bool _hapticCueEnabled = true;
  bool _didAnnounceCompletion = false;
  int _lastObservedPhaseIndex = -1;
  int _lastAnnouncedSeconds = -1;

  @override
  void initState() {
    super.initState();
    _initializeCueSettings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) {
      return;
    }
    _didInit = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    WorkoutBuilderRoutine? routine;
    WorkoutBuilderResumeSession? resumeSession;

    if (args is WorkoutBuilderResumeSession) {
      routine = args.routine;
      resumeSession = args;
    } else if (args is WorkoutBuilderRoutine) {
      routine = args;
    }

    if (routine == null) {
      _showMessage('Workout data missing.');
      return;
    }

    _routine = routine;
    _timeline = _buildTimeline(routine);
    _phaseIndex = 0;
    _remainingSeconds = _timeline.isEmpty ? 0 : _timeline.first.durationSeconds;

    if (resumeSession != null && _timeline.isNotEmpty) {
      final maxIndex = _timeline.length - 1;
      _phaseIndex = resumeSession.phaseIndex.clamp(0, maxIndex);
      final currentDuration = _timeline[_phaseIndex].durationSeconds;
      _remainingSeconds = resumeSession.remainingSeconds.clamp(0, currentDuration);
      if (_remainingSeconds == 0) {
        _remainingSeconds = currentDuration;
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    if (_isComplete || !_hasProgressToResume) {
      unawaited(_settingsService.clearWorkoutBuilderResumeSession());
    } else {
      unawaited(_persistResumeSnapshot());
    }
    _cueService.dispose();
    super.dispose();
  }

  bool get _hasProgressToResume {
    if (_timeline.isEmpty || _isComplete) {
      return false;
    }

    final currentDuration = _currentPhase.durationSeconds;
    final progressedCurrent = _remainingSeconds < currentDuration;
    return _phaseIndex > 0 || progressedCurrent;
  }

  Future<void> _persistResumeSnapshot() async {
    final routine = _routine;
    if (routine == null || !_hasProgressToResume) {
      await _settingsService.clearWorkoutBuilderResumeSession();
      return;
    }

    final snapshot = WorkoutBuilderResumeSession(
      routine: routine,
      phaseIndex: _phaseIndex,
      remainingSeconds: _remainingSeconds,
      savedAt: DateTime.now(),
    );

    await _settingsService.saveWorkoutBuilderResumeSession(snapshot);
  }

  Future<void> _initializeCueSettings() async {
    try {
      final settings = await _settingsService.load();
      await _cueService.updateSettings(
        volume: settings.voiceCueVolume,
        speechRate: settings.voiceCueRate,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _voiceCueEnabled = _cueService.supportsVoiceCues && settings.voiceCueEnabled;
        _hapticCueEnabled = settings.hapticCueEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not load cue settings. Using defaults.');
    }
  }

  String _phaseVoiceCueText(_BuilderPhase phase) {
    if (phase.type == _BuilderPhaseType.rest) {
      return 'Rest';
    }
    return phase.exercise.name;
  }

  Future<void> _handleWorkoutCues() async {
    if (_isRunning && _phaseIndex != _lastObservedPhaseIndex) {
      _lastObservedPhaseIndex = _phaseIndex;
      if (!_isComplete) {
        if (_hapticCueEnabled) {
          await HapticFeedback.mediumImpact();
        }
        await _cueService.playPhaseCompletionBeep();
        if (_voiceCueEnabled) {
          try {
            final phase = _currentPhase;
            if (phase.type == _BuilderPhaseType.rest) {
              await _cueService.announceRest(shouldSpeak: true);
            } else {
              await _cueService.announceExercise(
                _phaseVoiceCueText(phase),
                shouldSpeak: true,
              );
            }
          } on CueServiceException catch (e) {
            _showMessage(e.message);
          }
        }
      }
    }

    if (_isRunning && _remainingSeconds != _lastAnnouncedSeconds) {
      _lastAnnouncedSeconds = _remainingSeconds;
      if (_remainingSeconds > 0 && _remainingSeconds <= 5) {
        if (_hapticCueEnabled) {
          if (_remainingSeconds <= 3) {
            await HapticFeedback.lightImpact();
          } else {
            await HapticFeedback.selectionClick();
          }
        }
        if (_remainingSeconds == 1) {
          await _cueService.playCountdownFinalBeep();
        } else {
          await _cueService.playCountdownBeep();
        }
        if (_voiceCueEnabled) {
          try {
            await _cueService.speakCount(_remainingSeconds, shouldSpeak: true);
          } on CueServiceException catch (e) {
            _showMessage(e.message);
          }
        }
      }
    }

    if (_isComplete && !_didAnnounceCompletion) {
      _didAnnounceCompletion = true;
      if (_hapticCueEnabled) {
        await HapticFeedback.heavyImpact();
      }
      await _cueService.playWorkoutCompletionBeep();
      if (_voiceCueEnabled) {
        try {
          await _cueService.announceCompletion();
        } on CueServiceException catch (e) {
          _showMessage(e.message);
        }
      }
      return;
    }

    if (!_isComplete) {
      _didAnnounceCompletion = false;
    }
  }

  List<_BuilderPhase> _buildTimeline(WorkoutBuilderRoutine routine) {
    final phases = <_BuilderPhase>[];

    for (var i = 0; i < routine.exercises.length; i++) {
      final exercise = routine.exercises[i];
      phases.add(
        _BuilderPhase(
          type: _BuilderPhaseType.work,
          durationSeconds: exercise.workSeconds,
          exerciseIndex: i,
          exercise: exercise,
          label: exercise.name,
        ),
      );

      if (exercise.restSeconds > 0) {
        phases.add(
          _BuilderPhase(
            type: _BuilderPhaseType.rest,
            durationSeconds: exercise.restSeconds,
            exerciseIndex: i,
            exercise: exercise,
            label: 'Rest',
          ),
        );
      }
    }

    return phases;
  }

  _BuilderPhase get _currentPhase {
    if (_timeline.isEmpty || _phaseIndex < 0 || _phaseIndex >= _timeline.length) {
      return _BuilderPhase(
        type: _BuilderPhaseType.complete,
        durationSeconds: 0,
        exerciseIndex: 0,
        exercise: const WorkoutBuilderExercise(
          name: 'Complete',
          workSeconds: 0,
          restSeconds: 0,
        ),
        label: 'Workout Complete',
      );
    }
    return _timeline[_phaseIndex];
  }

  bool get _isComplete => _currentPhase.type == _BuilderPhaseType.complete;

  List<Color> get _phasePalette {
    switch (_currentPhase.type) {
      case _BuilderPhaseType.work:
        return const [Color(0xFF8B1A2A), Color(0xFFFF5A5F)];
      case _BuilderPhaseType.rest:
        return const [Color(0xFF0E4D6B), Color(0xFF2AB7CA)];
      case _BuilderPhaseType.complete:
        return const [Color(0xFF333333), Color(0xFF666666)];
    }
  }

  _BuilderPhase get _nextPhase {
    final nextIndex = _phaseIndex + 1;
    if (nextIndex >= 0 && nextIndex < _timeline.length) {
      return _timeline[nextIndex];
    }
    return _currentPhase;
  }

  int get _totalSeconds => _timeline.fold<int>(0, (sum, phase) => sum + phase.durationSeconds);

  int get _elapsedSeconds {
    final beforeCurrent = _timeline
        .take(_phaseIndex.clamp(0, _timeline.length))
        .fold<int>(0, (sum, phase) => sum + phase.durationSeconds);

    final currentElapsed =
        (_currentPhase.durationSeconds - _remainingSeconds).clamp(0, _currentPhase.durationSeconds);

    return beforeCurrent + currentElapsed;
  }

  double get _totalProgress {
    final total = _totalSeconds;
    if (total <= 0) {
      return 0;
    }
    return (_elapsedSeconds / total).clamp(0, 1);
  }

  void _start() {
    if (_timeline.isEmpty) {
      return;
    }

    if (_isComplete) {
      _phaseIndex = 0;
      _remainingSeconds = _timeline.first.durationSeconds;
    }

    _remainingSeconds = _remainingSeconds == 0
        ? _currentPhase.durationSeconds
        : _remainingSeconds;

    _ticker?.cancel();
    setState(() {
      _isRunning = true;
    });

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning) {
        return;
      }

      setState(() {
        _remainingSeconds -= 1;
        if (_remainingSeconds <= 0) {
          _moveToNextPhase();
        }
      });

      unawaited(_handleWorkoutCues());
      unawaited(_persistResumeSnapshot());
    });

    unawaited(_handleWorkoutCues());
    unawaited(_persistResumeSnapshot());
  }

  void _pause() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
    });
    unawaited(_persistResumeSnapshot());
  }

  void _stopAndReset() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
      _phaseIndex = 0;
      _remainingSeconds = _timeline.isEmpty ? 0 : _timeline.first.durationSeconds;
      _lastAnnouncedSeconds = -1;
      _lastObservedPhaseIndex = -1;
      _didAnnounceCompletion = false;
    });
    unawaited(_settingsService.clearWorkoutBuilderResumeSession());
  }

  void _skip() {
    if (_timeline.isEmpty || _isComplete) {
      return;
    }
    setState(_moveToNextPhase);
    unawaited(_handleWorkoutCues());
    unawaited(_persistResumeSnapshot());
  }

  void _moveToNextPhase() {
    if (_phaseIndex < _timeline.length - 1) {
      _phaseIndex += 1;
      _remainingSeconds = _timeline[_phaseIndex].durationSeconds;
      return;
    }

    _phaseIndex = _timeline.length;
    _remainingSeconds = 0;
    _isRunning = false;
    _ticker?.cancel();
    unawaited(_settingsService.clearWorkoutBuilderResumeSession());
  }

  WorkoutPhaseType _mapPhaseType(_BuilderPhaseType type) {
    switch (type) {
      case _BuilderPhaseType.work:
        return WorkoutPhaseType.work;
      case _BuilderPhaseType.rest:
        return WorkoutPhaseType.rest;
      case _BuilderPhaseType.complete:
        return WorkoutPhaseType.complete;
    }
  }

  WorkoutPhase _toWorkoutPhase(_BuilderPhase phase) {
    return WorkoutPhase(
      type: _mapPhaseType(phase.type),
      durationSeconds: phase.durationSeconds,
      label: phase.label,
    );
  }

  String _phaseHeaderSubtitle(_BuilderPhase phase) {
    if (_isRunning) {
      return 'Workout in progress';
    }
    if (phase.type == _BuilderPhaseType.complete) {
      return 'Session complete';
    }
    return 'Push limits. See results.';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final routine = _routine;
    if (routine == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
            ),
          ),
          child: const Center(
            child: Text(
              'Unable to load workout.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final current = _currentPhase;
    final palette = _phasePalette;
    final nextPhase = _nextPhase;
    final accentColor = current.type == _BuilderPhaseType.rest
        ? const Color(0xFF60A5FA)
        : palette.first;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[0], const Color(0xFF0D121C), palette[1]],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (Navigator.of(context).canPop())
                      const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _phaseHeaderSubtitle(current),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _ExerciseHeroCard(
                      mediaPath: current.type == _BuilderPhaseType.work
                          ? current.exercise.mediaPath
                          : '',
                      remainingSeconds: _remainingSeconds,
                      totalSeconds: current.durationSeconds,
                      phaseLabel: current.label,
                      isRestPhase: current.type == _BuilderPhaseType.rest,
                      palette: palette,
                      phaseBadge: PhaseBadge(
                        icon: current.type == _BuilderPhaseType.rest
                            ? Icons.pause_rounded
                            : Icons.fitness_center_rounded,
                        label: current.type == _BuilderPhaseType.rest
                            ? 'REST'
                            : 'WORK',
                        accent: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _totalProgress,
                        minHeight: 8,
                        valueColor: AlwaysStoppedAnimation(accentColor),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exercise: ${current.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    if (!_isComplete)
                      _InfoCard(
                        nextLabel: nextPhase.label,
                        nextDuration: nextPhase.durationSeconds,
                        remainingSeconds: _remainingSeconds,
                      ),
                    const SizedBox(height: 20),
                    _ControlBar(
                      running: _isRunning,
                      complete: _isComplete,
                      palette: palette,
                      onStartPause: _isRunning ? _pause : (_isComplete ? _stopAndReset : _start),
                      onReset: _stopAndReset,
                      onSkip: _skip,
                    ),
                    const SizedBox(height: 24),
                    WorkoutTimeline(
                      timeline: _timeline.map(_toWorkoutPhase).toList(),
                      currentIndex: _phaseIndex,
                      currentRemainingSeconds: _remainingSeconds,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseHeroCard extends StatelessWidget {
  const _ExerciseHeroCard({
    required this.mediaPath,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.phaseLabel,
    required this.isRestPhase,
    required this.palette,
    required this.phaseBadge,
  });

  final String mediaPath;
  final int remainingSeconds;
  final int totalSeconds;
  final String phaseLabel;
  final bool isRestPhase;
  final List<Color> palette;
  final Widget phaseBadge;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.6;
    final hasMedia = !isRestPhase && mediaPath.trim().isNotEmpty;
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final accentColor = isRestPhase ? const Color(0xFF60A5FA) : palette.first;

    return SizedBox(
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasMedia)
              Image.file(
                File(mediaPath.trim()),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildGradientBackground(),
              )
            else
              _buildGradientBackground(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45, Colors.black87],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: phaseBadge,
            ),
            Center(
              child: _TimerOverlay(
                remainingSeconds: remainingSeconds,
                progress: progress,
                accentColor: accentColor,
                phaseLabel: phaseLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette[0], const Color(0xFF0D121C), palette[1]],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.self_improvement_rounded,
          color: Colors.white.withValues(alpha: 0.2),
          size: 64,
        ),
      ),
    );
  }
}

class _TimerOverlay extends StatelessWidget {
  const _TimerOverlay({
    required this.remainingSeconds,
    required this.progress,
    required this.accentColor,
    required this.phaseLabel,
  });

  final int remainingSeconds;
  final double progress;
  final Color accentColor;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      phaseLabel.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(accentColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.nextLabel,
    required this.nextDuration,
    required this.remainingSeconds,
  });

  final String nextLabel;
  final int nextDuration;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoColumn(
              icon: Icons.local_fire_department_rounded,
              label: 'Next',
              value: '$nextLabel (${nextDuration}s)',
              accent: const Color(0xFFFF8A1E),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _InfoColumn(
              icon: Icons.timer_rounded,
              label: 'Remaining',
              value: '$remainingSeconds seconds',
              accent: const Color(0xFF60A5FA),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.running,
    required this.complete,
    required this.palette,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
  });

  final bool running;
  final bool complete;
  final List<Color> palette;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette[0], palette[1]]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: palette.first.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: onStartPause,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(running ? 'Pause' : complete ? 'Restart' : 'Start'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('Skip'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
