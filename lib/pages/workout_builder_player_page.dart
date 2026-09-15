import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/pages/audio_settings_page.dart';
import 'package:my_app/services/gemini_voice_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/music_service.dart';
import 'package:my_app/services/sfx_service.dart';
import 'package:my_app/services/workout_foreground_service.dart';
import 'package:my_app/services/community_firestore_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:my_app/widgets/countdown_bar.dart';
import 'package:my_app/widgets/music_controls.dart';
import 'package:my_app/widgets/music_folder_picker.dart';
import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/workout_timeline.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

enum _BuilderPhaseType {
  /// A timed work interval that counts down.
  work,

  /// A manual-rep set: the athlete taps SET COMPLETE when finished; there is no
  /// wall-clock countdown in the app.
  reps,

  rest,
  complete,
}

class _BuilderPhase {
  const _BuilderPhase({
    required this.type,
    required this.durationSeconds,
    required this.exerciseIndex,
    required this.exercise,
    required this.label,
    this.setNumber,
    this.totalSets,
  });

  final _BuilderPhaseType type;

  /// Nominal seconds for the phase. For timed phases this is the real countdown
  /// length; for reps phases it is only an estimate used for progress/duration
  /// math (never ticked down).
  final int durationSeconds;
  final int exerciseIndex;
  final WorkoutBuilderExercise exercise;
  final String label;

  /// 1-based index of the set within its exercise (reps phases only).
  final int? setNumber;

  /// Total number of sets for the exercise (reps phases only).
  final int? totalSets;

  bool get isReps => type == _BuilderPhaseType.reps;
  bool get isWork => type == _BuilderPhaseType.work;
}

class WorkoutBuilderPlayerPage extends StatefulWidget {
  const WorkoutBuilderPlayerPage({super.key});

  @override
  State<WorkoutBuilderPlayerPage> createState() => _WorkoutBuilderPlayerPageState();
}

class _WorkoutBuilderPlayerPageState extends State<WorkoutBuilderPlayerPage>
    with WidgetsBindingObserver {
  late AudioEngine _audioEngine;
  late MusicService _musicService;
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
  List<String> _exerciseNames = [];
  List<String> _exerciseImageAssets = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _musicService = MusicService();
    _audioEngine = AudioEngine(
      voice: GeminiVoiceService(),
      sfx: SfxService(),
      music: _musicService,
    );
    _initializeCueSettings();
    _listenForNotificationActions();
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

    _exerciseNames = _buildExerciseNames();
    if (_exerciseNames.isNotEmpty) {
      final workDurations = routine.exercises.map((e) => e.workSeconds).toList();
      final restDurations = routine.exercises.map((e) => e.restSeconds).toList();
      final fingerprint = WorkoutFingerprint(
        workoutId: routine.id,
        exerciseNames: _exerciseNames,
        exerciseDurations: workDurations,
        restDurations: restDurations,
        recoveryDurations: List.filled(routine.exercises.length, 0),
      );
      unawaited(_audioEngine.generateWorkoutVoice(
        fingerprint: fingerprint,
        exerciseNames: _exerciseNames,
        workoutName: routine.name,
      ));
    }

    unawaited(_loadExerciseMedia());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (_isRunning) {
        WorkoutForegroundService.instance.promoteToForeground();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (_isRunning) {
        // Refresh the chronometer base so the next promote matches the
        // on-screen countdown instead of a stale pre-background value.
        WorkoutForegroundService.instance.syncTime(_remainingSeconds);
      }
      WorkoutForegroundService.instance.demoteToBackground();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    _ticker?.cancel();
    try { WorkoutForegroundService.instance.stop(); } catch (_) {}
    if (_isComplete || !_hasProgressToResume) {
      unawaited(_settingsService.clearWorkoutBuilderResumeSession());
    } else {
      unawaited(_persistResumeSnapshot());
    }
    _audioEngine.dispose();
    _musicService.dispose();
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
      await _audioEngine.initialize();

      final settings = await _settingsService.load();

      if (!mounted) {
        return;
      }

      setState(() {
        _voiceCueEnabled = settings.voiceCueEnabled;
        _hapticCueEnabled = settings.hapticCueEnabled;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage('Could not load cue settings. Using defaults.');
    }
  }

  void _listenForNotificationActions() {
    WorkoutForegroundService.instance.onAction.listen((action) {
      switch (action) {
        case 'pause':
          if (_isRunning) {
            _pause();
            WorkoutForegroundService.instance.update(isPaused: true);
          }
        case 'resume':
          if (!_isRunning && !_isComplete && _phaseIndex > 0) {
            _start();
            WorkoutForegroundService.instance.update(isPaused: false);
          }
        case 'skip':
          _skip();
        case 'stop':
          _stopAndReset();
        case 'music_toggle':
        case 'music_stop':
          _musicService.stop();
          setState(() {});
      }
    });
  }

  List<String> _buildExerciseNames() {
    final names = <String>[];
    for (final phase in _timeline) {
      if (phase.isWork || phase.isReps) {
        if (!names.contains(phase.exercise.name)) {
          names.add(phase.exercise.name);
        }
      }
    }
    return names;
  }

  String _phaseVoiceCueText(_BuilderPhase phase) {
    if (phase.type == _BuilderPhaseType.rest) {
      return 'Rest';
    }
    if (phase.isReps) {
      return '${phase.label}, set ${phase.setNumber ?? 1} of ${phase.totalSets ?? 1}';
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
        final phase = _currentPhase;
        if (phase.type == _BuilderPhaseType.rest) {
          _audioEngine.announceRest();
        } else {
          _audioEngine.onExerciseChanged(phase.exerciseIndex);
          _audioEngine.announceExercise(
            _phaseVoiceCueText(phase),
            shouldSpeak: _voiceCueEnabled,
          );
        }
      }
    }

    if (_isRunning && _remainingSeconds != _lastAnnouncedSeconds) {
      _lastAnnouncedSeconds = _remainingSeconds;

      if (_remainingSeconds == 0) {
        if (_hapticCueEnabled) {
          await HapticFeedback.mediumImpact();
        }
        await _audioEngine.playTransitionAtZero();
      } else if (_remainingSeconds >= 1 && _remainingSeconds <= 5) {
        if (_hapticCueEnabled) {
          if (_remainingSeconds <= 3) {
            await HapticFeedback.lightImpact();
          } else {
            await HapticFeedback.selectionClick();
          }
        }
        if (_remainingSeconds <= 3) {
          await _audioEngine.playCountdownTick(_remainingSeconds);
        }
        await _audioEngine.speakCount(_remainingSeconds, shouldSpeak: _voiceCueEnabled);
      }
    }

    if (_isComplete && !_didAnnounceCompletion) {
      _didAnnounceCompletion = true;
      if (_hapticCueEnabled) {
        await HapticFeedback.heavyImpact();
      }
      await _audioEngine.announceCompletion();
      return;
    }
  }

  List<_BuilderPhase> _buildTimeline(WorkoutBuilderRoutine routine) {
    final phases = <_BuilderPhase>[];

    for (var i = 0; i < routine.exercises.length; i++) {
      final exercise = routine.exercises[i];
      final isReps = exercise.type == WorkoutExerciseType.reps;
      final exerciseSets = exercise.sets.clamp(1, 50);

      for (var s = 1; s <= exerciseSets; s++) {
        final isFinalSet = s == exerciseSets;
        phases.add(
          _BuilderPhase(
            type: isReps ? _BuilderPhaseType.reps : _BuilderPhaseType.work,
            durationSeconds: exercise.assumedSetSeconds,
            exerciseIndex: i,
            exercise: exercise,
            label: exercise.name,
            setNumber: s,
            totalSets: exerciseSets,
          ),
        );

        // Rest bridges to the next set, or to the next exercise when this
        // exercise has a single set. Only the final set of a multi-set exercise
        // moves straight to the next exercise without a rest.
        final hasRestRound = exerciseSets > 1
            ? !isFinalSet && exercise.restSeconds > 0
            : exercise.restSeconds > 0;
        if (hasRestRound) {
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
    }

    return phases;
  }

  Future<void> _loadExerciseMedia() async {
    try {
      final assetKeys = await _bundleAssetKeys();
      final imageAssets =
          assetKeys
              .where(
                (path) =>
                    path.startsWith('assets/exercises/images/') &&
                    _isSupportedImageAsset(path),
              )
              .toList()
            ..sort();

      if (!mounted) {
        return;
      }
      setState(() {
        _exerciseImageAssets = imageAssets;
      });
    } catch (_) {
      // Asset manifest unavailable (e.g. headless test runs): fall back to no
      // bundled related media. User-attached media still works.
      return;
    }
  }

  Future<List<String>> _bundleAssetKeys() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      return manifest.listAssets();
    } catch (_) {
      // Older Flutter toolchains served a JSON manifest instead.
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;
      return manifestMap.keys.toList();
    }
  }

  bool _isSupportedImageAsset(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.gif') ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp');
  }

  /// Resolves the media to show for an exercise: the user-attached media file
  /// wins, otherwise a bundled asset (GIF/image) whose file name matches the
  /// exercise name keywords is used, otherwise an empty string (gradient).
  String _resolveMediaForExercise(WorkoutBuilderExercise exercise) {
    final userPath = exercise.mediaPath.trim();
    if (userPath.isNotEmpty) {
      return userPath;
    }
    final keywords = _keywordsForName(exercise.name);
    if (keywords.isEmpty) {
      return '';
    }
    for (final asset in _exerciseImageAssets) {
      final baseName = _assetBaseName(asset).toLowerCase();
      if (keywords.every(baseName.contains)) {
        return asset;
      }
    }
    return '';
  }

  List<String> _keywordsForName(String name) {
    final tokens = name
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((token) => token.length >= 3)
        .toList();
    const stopWords = {
      'the',
      'and',
      'with',
      'for',
      'your',
      'you',
      'get',
      'dumbbell',
      'machine',
    };
    return tokens.where((token) => !stopWords.contains(token)).toList();
  }

  String _assetBaseName(String assetPath) {
    final lastSlash = assetPath.lastIndexOf('/');
    final String fileName;
    if (lastSlash >= 0) {
      fileName = assetPath.substring(lastSlash + 1);
    } else {
      fileName = assetPath;
    }
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
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
      case _BuilderPhaseType.reps:
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
    WakelockPlus.enable();
    HapticFeedback.heavyImpact();

    // Start foreground service
    unawaited(_startForegroundService(_phaseIndex));

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_isRunning) {
        return;
      }

      setState(() {
        // Reps phases never auto-advance: the athlete completes each set
        // manually. All other phases tick down as usual.
        if (_currentPhase.isReps) {
          return;
        }
        _remainingSeconds -= 1;
        if (_remainingSeconds <= 0) {
          _moveToNextPhase();
        }
      });

      _pushNotificationState();

      unawaited(_handleWorkoutCues());
      unawaited(_persistResumeSnapshot());
    });

    unawaited(_handleWorkoutCues());
    unawaited(_persistResumeSnapshot());
  }

  Future<void> _startForegroundService(int phaseIndex) async {
    try {
      final phase = _timeline[phaseIndex];
      await WorkoutForegroundService.instance.start(
        workoutName: _routine?.name ?? 'Workout',
        exerciseName: _notificationExerciseName(phase),
        remainingSeconds: _remainingSeconds,
        currentSet: _currentExerciseOrdinal(),
        totalSets: _totalExerciseCount,
        isMusicPlaying: _musicService.player.playing,
      );
    } catch (_) {
      // Foreground service unavailable (tests / unsupported platforms).
    }
  }

  void _pause() {
    _ticker?.cancel();
    setState(() {
      _isRunning = false;
    });
    WakelockPlus.disable();
    unawaited(_persistResumeSnapshot());
  }

  /// Number of work/reps phases in the timeline (the real "total sets").
  int get _totalExerciseCount =>
      _timeline.where((p) => p.isWork || p.isReps).length;

  /// Ordinal (1-based) of the current exercise, or 0 when the current phase is
  /// not a work/reps phase — so the notification omits a misleading set label
  /// during warmup/rest/cooldown.
  int _currentExerciseOrdinal() {
    if (_phaseIndex >= _timeline.length) return 0;
    if (!_timeline[_phaseIndex].isWork && !_timeline[_phaseIndex].isReps) return 0;

    int ordinal = 0;
    for (int i = 0; i <= _phaseIndex; i++) {
      if (_timeline[i].isWork || _timeline[i].isReps) ordinal++;
    }
    return ordinal;
  }

  /// Notification title for the current phase. Reps phases surface the active
  /// set so the athlete knows which set they are on from the lock screen.
  String _notificationExerciseName(_BuilderPhase phase) {
    if (phase.isReps) {
      return '${phase.label} • Set ${phase.setNumber ?? 1}/${phase.totalSets ?? 1}';
    }
    return phase.label;
  }

  /// Push timer state to the persistent notification. Safe to call every tick;
  /// the service de-dupes on stable content and the system renders the
  /// countdown via its chronometer rather than a per-second re-post.
  void _pushNotificationState() {
    if (!WorkoutForegroundService.instance.isRunning) return;
    if (_phaseIndex >= _timeline.length) return;
    final phase = _timeline[_phaseIndex];
    final ordinal = _currentExerciseOrdinal();
    WorkoutForegroundService.instance.update(
      exerciseName: _notificationExerciseName(phase),
      remainingSeconds: _remainingSeconds,
      currentSet: ordinal,
      totalSets: ordinal == 0 ? 0 : _totalExerciseCount,
      isPaused: !_isRunning,
      isMusicPlaying: _musicService.player.playing,
    );
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
    WakelockPlus.disable();
    try { WorkoutForegroundService.instance.stop(); } catch (_) {}
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

  /// Marks the current manual-rep set as complete and advances to the rest
  /// phase, the next set of the same exercise, the next exercise, or workout
  /// completion — exactly as if a timed set had counted down to zero.
  void _completeRepSet() {
    if (_timeline.isEmpty || _isComplete) {
      return;
    }
    if (!_currentPhase.isReps) {
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
    try { WorkoutForegroundService.instance.stop(); } catch (_) {}
    unawaited(_settingsService.clearWorkoutBuilderResumeSession());
  }

  WorkoutPhaseType _mapPhaseType(_BuilderPhaseType type) {
    switch (type) {
      case _BuilderPhaseType.work:
      case _BuilderPhaseType.reps:
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
      setNumber: phase.setNumber,
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

  Future<void> _shareWorkout() async {
    final routine = _routine;
    if (routine == null) return;

    final firestoreId = await CommunityFirestoreService.instance.shareRoutine(routine);

    if (!mounted) return;

    if (firestoreId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to share workout. Check your connection.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final link = 'fitpulse://workout/$firestoreId';
    await Clipboard.setData(ClipboardData(text: link));
    await SharePlus.instance.share(ShareParams(text: 'Try my workout "${routine.name}"! $link'));

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Workout shared! Link copied to clipboard.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _openMusicPicker() async {
    await showMusicSongSheet(context, _musicService);
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
    final isRepsPhase = current.isReps;
    final accentColor = current.type == _BuilderPhaseType.rest
        ? const Color(0xFF60A5FA)
        : palette.first;
    final currentMediaPath = (current.isWork || current.isReps)
        ? _resolveMediaForExercise(current.exercise)
        : '';
    final nextLabel = nextPhase.label;
    final nextDuration = nextPhase.durationSeconds;
    final nextInfo = nextPhase.isReps
        ? '${nextPhase.exercise.name} · ${nextPhase.setNumber ?? 1}/${nextPhase.totalSets ?? 1}'
        : '$nextLabel (${nextDuration}s)';
    final remainingInfo = isRepsPhase
        ? '${current.exercise.targetReps} reps'
        : '$_remainingSeconds seconds';

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
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AudioSettingsPage(
                                    audioEngine: _audioEngine,
                                    settings: AppSettings.defaults(),
                                    onSettingsChanged: () {},
                                    currentFingerprint: _audioEngine.currentFingerprint,
                                    currentExerciseNames: _exerciseNames,
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(
                              Icons.tune_rounded,
                              color: Colors.white,
                              size: 20,
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
                        const SizedBox(width: 8),
                        Expanded(
                          child: MusicControls(
                            musicService: _musicService,
                            onOpenPicker: _openMusicPicker,
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
                          mediaPath: currentMediaPath,
                          remainingSeconds: _remainingSeconds,
                          totalSeconds: current.durationSeconds,
                          phaseLabel: current.label,
                          isRestPhase: current.type == _BuilderPhaseType.rest,
                          isRepsPhase: isRepsPhase,
                          setNumber: current.setNumber,
                          totalSets: current.totalSets,
                          targetReps: isRepsPhase ? current.exercise.targetReps : 0,
                          palette: palette,
                          elapsedSeconds: _elapsedSeconds,
                          totalWorkoutSeconds: _totalSeconds,
                          isComplete: _isComplete,
                          phaseBadge: PhaseBadge(
                            icon: current.type == _BuilderPhaseType.rest
                                ? Icons.pause_rounded
                                : isRepsPhase
                                    ? Icons.fitness_center_rounded
                                    : Icons.timer_outlined,
                            label: current.type == _BuilderPhaseType.rest
                                ? 'REST'
                                : isRepsPhase
                                    ? 'REPS'
                                    : 'WORK',
                            accent: accentColor,
                          ),
                        ),
                        if (isRepsPhase) ...[
                          const SizedBox(height: 16),
                          _RepSetCompleteButton(
                            setNumber: current.setNumber ?? 1,
                            totalSets: current.totalSets ?? 1,
                            targetReps: current.exercise.targetReps,
                            onPressed: _completeRepSet,
                          ),
                        ],
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
                            nextValue: nextInfo,
                            remainingValue: remainingInfo,
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
            if (_isComplete)
              _BuilderCompletionOverlay(
                totalSeconds: _totalSeconds,
                completedExercises: _timeline
                    .where((p) => p.isWork || p.isReps)
                    .length,
                routineName: routine.name,
                onDone: () {
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                },
                onShare: _shareWorkout,
              ),
            if (!_isRunning && !_isComplete && _phaseIndex > 0)
              _BuilderPauseOverlay(
                onResume: _start,
                onRestart: _stopAndReset,
                onQuit: () {
                  _stopAndReset();
                  final navigator = Navigator.of(context);
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                },
              ),
          ],
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
    required this.isRepsPhase,
    required this.setNumber,
    required this.totalSets,
    required this.targetReps,
    required this.palette,
    required this.phaseBadge,
    required this.elapsedSeconds,
    required this.totalWorkoutSeconds,
    required this.isComplete,
  });

  final String mediaPath;
  final int remainingSeconds;
  final int totalSeconds;
  final String phaseLabel;
  final bool isRestPhase;
  final bool isRepsPhase;
  final int? setNumber;
  final int? totalSets;
  final int targetReps;
  final List<Color> palette;
  final Widget phaseBadge;
  final int elapsedSeconds;
  final int totalWorkoutSeconds;
  final bool isComplete;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.5;
    final hasMedia = !isRestPhase && mediaPath.trim().isNotEmpty;
    final isBundledAsset = mediaPath.trim().startsWith('assets/exercises/');
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;

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
              ClipRRect(
                borderRadius: BorderRadius.circular(0),
                child: isBundledAsset
                    ? Image.asset(
                        mediaPath.trim(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildGradientBackground(),
                      )
                    : Image.file(
                        File(mediaPath.trim()),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildGradientBackground(),
                      ),
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
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: isRepsPhase
                    ? _RepSetPanel(
                        setNumber: setNumber ?? 1,
                        totalSets: totalSets ?? 1,
                        targetReps: targetReps,
                        exerciseName: phaseLabel,
                      )
                    : isComplete
                        ? const SizedBox.shrink()
                        : CountdownBar(
                        progress: progress,
                        seconds: remainingSeconds,
                        phaseLabel: phaseLabel,
                        gradient: palette,
                        elapsedSeconds: elapsedSeconds,
                        totalSeconds: totalWorkoutSeconds,
                      ),
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

class _RepSetPanel extends StatelessWidget {
  const _RepSetPanel({
    required this.setNumber,
    required this.totalSets,
    required this.targetReps,
    required this.exerciseName,
  });

  final int setNumber;
  final int totalSets;
  final int targetReps;
  final String exerciseName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  exerciseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'SET $setNumber/$totalSets',
                style: TextStyle(
                  color: const Color(0xFFFF8A1E),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'TARGET $targetReps REPS',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RepSetCompleteButton extends StatelessWidget {
  const _RepSetCompleteButton({
    required this.setNumber,
    required this.totalSets,
    required this.targetReps,
    required this.onPressed,
  });

  final int setNumber;
  final int totalSets;
  final int targetReps;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFFFF8A1E),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.4,
          ),
          shadowColor: Colors.transparent,
        ),
        icon: const Icon(Icons.check_circle_rounded, size: 26),
        label: Text('SET $setNumber/$totalSets COMPLETE'),
      ),
    );
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
    required this.nextValue,
    required this.remainingValue,
  });

  final String nextValue;
  final String remainingValue;

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
              value: nextValue,
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
              label: 'In this set',
              value: remainingValue,
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

class _BuilderCompletionOverlay extends StatelessWidget {
  const _BuilderCompletionOverlay({
    required this.totalSeconds,
    required this.completedExercises,
    required this.routineName,
    required this.onDone,
    required this.onShare,
  });

  final int totalSeconds;
  final int completedExercises;
  final String routineName;
  final VoidCallback onDone;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final totalMinutes = totalSeconds ~/ 60;
    final totalSecs = totalSeconds % 60;
    final estimatedCalories = (totalSeconds * 0.15).round();

    return Container(
      color: Colors.black.withValues(alpha: 0.85),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF22C55E).withValues(alpha: 0.4),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Workout Complete',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$totalMinutes min $totalSecs sec',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CompletionStat(
                      icon: Icons.local_fire_department_rounded,
                      value: '$estimatedCalories',
                      label: 'cal',
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.15),
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                    _CompletionStat(
                      icon: Icons.fitness_center_rounded,
                      value: '$completedExercises',
                      label: 'exercises',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onDone,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF8A1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Done',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onShare,
                  icon: const Icon(Icons.share_rounded, size: 20),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuilderPauseOverlay extends StatelessWidget {
  const _BuilderPauseOverlay({
    required this.onResume,
    required this.onRestart,
    required this.onQuit,
  });

  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _BuilderPauseButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              onTap: onResume,
              isPrimary: true,
            ),
            const SizedBox(height: 12),
            _BuilderPauseButton(
              icon: Icons.replay_rounded,
              label: 'Restart',
              onTap: onRestart,
              isPrimary: false,
            ),
            const SizedBox(height: 12),
            _BuilderPauseButton(
              icon: Icons.stop_rounded,
              label: 'Quit',
              onTap: onQuit,
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _BuilderPauseButton extends StatelessWidget {
  const _BuilderPauseButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFFF8A1E), Color(0xFFFF6B1E)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFF8A1E).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionStat extends StatelessWidget {
  const _CompletionStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFF8A1E), size: 20),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.5),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ],
    );
  }
}


