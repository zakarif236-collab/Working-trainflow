import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/cue_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/widgets/circular_countdown.dart';
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

class _WorkoutBuilderPlayerPageState extends State<WorkoutBuilderPlayerPage>
    with SingleTickerProviderStateMixin {
  final CueService _cueService = CueService();
  final SettingsService _settingsService = SettingsService();
  late final AnimationController _pulseController;

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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.97,
      upperBound: 1.03,
    );
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
    _pulseController.dispose();
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

  double get _phaseProgress {
    final total = _currentPhase.durationSeconds;
    if (total <= 0) {
      return 1;
    }
    return ((total - _remainingSeconds) / total).clamp(0, 1);
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
    _pulseController.repeat(reverse: true);

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
    _pulseController.stop();
    _pulseController.value = 1;
    unawaited(_persistResumeSnapshot());
  }

  void _stopAndReset() {
    _ticker?.cancel();
    _pulseController.stop();
    _pulseController.value = 1;
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
        child: Stack(
          children: [
            Positioned(
              top: -40,
              left: -30,
              child: GlowBlob(
                color: palette.first.withValues(alpha: 0.55),
              ),
            ),
            Positioned(
              bottom: -80,
              right: -40,
              child: GlowBlob(
                color: palette.last.withValues(alpha: 0.45),
              ),
            ),
            SafeArea(
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
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                style: const TextStyle(
                                  color: Colors.white54,
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
                        const SizedBox(height: 8),
                        _BuilderHeroSessionCard(
                          phase: current,
                          palette: palette,
                          isRunning: _isRunning,
                          countdown: ScaleTransition(
                            scale: _pulseController,
                            child: CircularCountdown(
                              progress: _phaseProgress,
                              seconds: _remainingSeconds,
                              phaseLabel: current.label,
                              subtitle: '${_remainingSeconds}s',
                              gradient: [palette.first, palette.last],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _BuilderActionControls(
                          running: _isRunning,
                          complete: _isComplete,
                          onStartPause: _isRunning ? _pause : _start,
                          onReset: _stopAndReset,
                          onSkip: _skip,
                        ),
                        const SizedBox(height: 12),
                        if (!_isComplete)
                          NextPhaseCard(phase: _toWorkoutPhase(nextPhase)),
                        const SizedBox(height: 12),
                        if (!_isComplete)
                          current.type == _BuilderPhaseType.rest
                              ? const _RestPhaseMessageCard(
                                  message:
                                      'Take a deep breath. Recover and get ready for the next push.',
                                )
                              : _ExerciseMediaPreview(
                                  path: current.exercise.mediaPath,
                                ),
                        const SizedBox(height: 12),
                        ProgressHeader(
                          progress: _totalProgress,
                          elapsed: _elapsedSeconds,
                          total: _totalSeconds,
                        ),
                        const SizedBox(height: 12),
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
          ],
        ),
      ),
    );
  }
}

class _BuilderHeroSessionCard extends StatelessWidget {
  const _BuilderHeroSessionCard({
    required this.phase,
    required this.palette,
    required this.isRunning,
    required this.countdown,
  });

  final _BuilderPhase phase;
  final List<Color> palette;
  final bool isRunning;
  final Widget countdown;

  @override
  Widget build(BuildContext context) {
    final accent = phase.type == _BuilderPhaseType.work
        ? const Color(0xFFFF5A5F)
        : phase.type == _BuilderPhaseType.rest
            ? const Color(0xFF2AB7CA)
            : const Color(0xFF666666);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: palette.first.withValues(alpha: 0.12),
            blurRadius: 40,
            spreadRadius: -4,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: -6,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isRunning
                    ? const Color(0xFF22C55E).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isRunning
                      ? const Color(0xFF22C55E).withValues(alpha: 0.30)
                      : Colors.white.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isRunning
                          ? const Color(0xFF22C55E)
                          : Colors.white54,
                      boxShadow: isRunning
                          ? [
                              BoxShadow(
                                color: const Color(0xFF22C55E)
                                    .withValues(alpha: 0.6),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isRunning ? 'Running' : 'Ready',
                    style: TextStyle(
                      color: isRunning
                          ? const Color(0xFF22C55E)
                          : Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: AspectRatio(
              aspectRatio: 1,
              child: countdown,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              PhaseBadge(
                icon: phase.type == _BuilderPhaseType.work
                    ? Icons.local_fire_department_rounded
                    : Icons.self_improvement_rounded,
                label: phase.label,
                accent: accent,
              ),
              const SizedBox(width: 8),
              PhaseBadge(
                icon: Icons.timer_rounded,
                label: '${phase.durationSeconds}s',
                accent: palette.last,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BuilderActionControls extends StatelessWidget {
  const _BuilderActionControls({
    required this.running,
    required this.complete,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
  });

  final bool running;
  final bool complete;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ControlButton(
                label: running ? 'Pause' : complete ? 'Restart' : 'Start',
                icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                primary: true,
                onPressed: onStartPause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ControlButton(
                label: 'Skip',
                icon: Icons.skip_next_rounded,
                primary: false,
                onPressed: onSkip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ControlButton(
                label: 'Reset',
                icon: Icons.replay_rounded,
                primary: false,
                onPressed: onReset,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }
}

class _ExerciseMediaPreview extends StatelessWidget {
  const _ExerciseMediaPreview({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    final cleaned = path.trim();
    if (cleaned.isEmpty) {
      return Container(
        height: 170,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: Colors.white.withValues(alpha: 0.04),
          border: Border.all(color: Colors.white24),
        ),
        child: const Text(
          'No GIF/image for this exercise',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(cleaned),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) {
          return Container(
            height: 170,
            alignment: Alignment.center,
            color: Colors.black26,
            child: const Text(
              'Could not load media preview',
              style: TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}

class _RestPhaseMessageCard extends StatelessWidget {
  const _RestPhaseMessageCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFB8FFE4).withValues(alpha: 0.12),
        border: Border.all(color: const Color(0xFF7FE6BB).withValues(alpha: 0.7)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.self_improvement_rounded, size: 34, color: Color(0xFF7FE6BB)),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExerciseHeroCard extends StatelessWidget {
  const _ExerciseHeroCard({
    required this.mediaPath,
    required this.remainingSeconds,
    required this.phaseLabel,
    required this.isRestPhase,
    required this.palette,
    required this.phaseBadge,
  });

  final String mediaPath;
  final int remainingSeconds;
  final String phaseLabel;
  final bool isRestPhase;
  final List<Color> palette;
  final Widget phaseBadge;

  @override
  Widget build(BuildContext context) {
    final hasMedia = !isRestPhase && mediaPath.trim().isNotEmpty;

    if (!hasMedia && !isRestPhase) {
      return CircularCountdown(
        progress: 0,
        seconds: remainingSeconds,
        phaseLabel: phaseLabel,
        subtitle: '${remainingSeconds}s',
        gradient: palette,
      );
    }

    return SizedBox(
      height: 280,
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
                colors: [Colors.transparent, Colors.black54],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: phaseBadge,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${remainingSeconds}s',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 48,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    shadows: [
                      Shadow(color: Colors.black87, blurRadius: 12),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
