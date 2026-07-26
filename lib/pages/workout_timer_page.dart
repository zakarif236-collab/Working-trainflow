import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_app/controllers/workout_controller.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/pages/audio_settings_page.dart';
import 'package:my_app/services/gemini_voice_service.dart';
import 'package:my_app/services/music_service.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:my_app/services/sfx_service.dart';
import 'package:my_app/widgets/home_timer_layout.dart';
import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/workout_timer_layout.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

const List<String> _calisthenicsWarmupMoves = [
  'Jumping jacks - 30s',
  'Arm circles - 30s',
  'Leg swings - 30s each leg',
  'High knees - 30s',
];

const List<List<String>> _calisthenicsWarmupAssetKeywords = [
  ['jumping', 'jacks'],
  ['arm', 'circles'],
  ['leg', 'swings'],
  ['high', 'knees'],
];

const List<String> _calisthenicsMainMoves = [
  'Jump squats',
  'Push-ups with shoulder tap',
  'Bear crawl',
  'Mountain climbers',
  'Burpee with push-up',
  'V-ups',
];

const List<String> _calisthenicsCooldownMoves = [
  'Child\'s pose - 20s',
  'Standing quad stretch - 20s each leg',
  'Forward fold - 20s',
];

const List<String> _hiitWorkMoves = [
  'Burpees',
  'Mountain climbers',
  'Jump squats',
  'High knees',
  'Skater jumps',
];

enum TimerMode { home, workout }

class WorkoutTimerPage extends StatefulWidget {
  const WorkoutTimerPage({
    super.key,
    this.launchConfig,
    this.timerMode = TimerMode.home,
  });

  final WorkoutConfig? launchConfig;
  final TimerMode timerMode;

  @override
  State<WorkoutTimerPage> createState() => _WorkoutTimerPageState();
}

class _WorkoutTimerPageState extends State<WorkoutTimerPage>
    with SingleTickerProviderStateMixin {
  late final WorkoutController _controller;
  late final MusicService _musicService;
  late final AudioEngine _audioEngine;
  late final SettingsService _settingsService;
  late final AnimationController _pulseController;
  Timer? _settingsPersistDebounce;

  WorkoutIntensity _selectedIntensity = WorkoutConfig.defaults.intensity;
  bool _voiceCueEnabled = true;
  bool _hapticCueEnabled = true;
  bool _muteVoiceWhileMusicPlays = true;
  bool _autoPhaseMusicProfileEnabled = true;
  double _voiceCueVolume = 1.0;
  double _voiceCueRate = 0.52;
  int _lastAnnouncedSeconds = -1;
  int _lastObservedPhaseIndex = -1;
  bool _didAnnounceCompletion = false;
  bool _didRecordCompletionStats = false;
  WorkoutConfig? _launchConfig;
  bool _didReadLaunchConfig = false;
  List<String> _exerciseImageAssets = const [];
  List<String> _exerciseVideoAssets = const [];
  String? _activeExerciseMediaPath;
  VideoPlayerController? _exerciseVideoController;
  String? _nextExerciseMediaPath;
  VideoPlayerController? _nextExerciseVideoController;
  bool _loadingExerciseMedia = false;
  bool _showCustomizationPanel = false;
  bool _hasStarted = false;
  List<String> _exerciseNames = [];

  @override
  void initState() {
    super.initState();
    _controller = WorkoutController();
    _musicService = MusicService();
    _settingsService = SettingsService();
    _audioEngine = AudioEngine(
      voice: GeminiVoiceService(),
      sfx: SfxService(),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
      lowerBound: 0.97,
      upperBound: 1.03,
    );

    _initializeFromSavedSettings();
    _loadExerciseMedia();

    _controller.addListener(_watchWorkoutErrors);
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _settingsPersistDebounce?.cancel();
    _controller.removeListener(_watchWorkoutErrors);
    _controller.dispose();
    _pulseController.dispose();
    _disposeExerciseVideoController();
    _disposeNextExerciseVideoController();
    _audioEngine.dispose();
    _musicService.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didReadLaunchConfig) {
      return;
    }

    _didReadLaunchConfig = true;
    final config = widget.launchConfig ??
        (ModalRoute.of(context)?.settings.arguments as WorkoutConfig?);
    if (config is WorkoutConfig) {
      _launchConfig = config;
      _controller.updateConfig(config);
      _selectedIntensity = config.intensity;
    }
  }

  @override
  void didUpdateWidget(WorkoutTimerPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = widget.launchConfig;
    if (next != null && next != oldWidget.launchConfig) {
      _launchConfig = next;
      _controller.stop(reset: true);
      _controller.updateConfig(next);
      _didAnnounceCompletion = false;
      _didRecordCompletionStats = false;
      setState(() {
        _selectedIntensity = next.intensity;
      });
    }
  }

  void _watchWorkoutErrors() {
    final message = _controller.takeError();
    if (message != null && mounted) {
      _showMessage(message);
    }

    if (_controller.isRunning) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 1;
    }

    _handleWorkoutCues();
    unawaited(_syncCurrentPhaseMedia());
  }

  Future<void> _loadExerciseMedia() async {
    setState(() {
      _loadingExerciseMedia = true;
    });

    try {
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      final manifestMap = jsonDecode(manifestContent) as Map<String, dynamic>;

      final imageAssets =
          manifestMap.keys
              .where(
                (path) =>
                    path.startsWith('assets/exercises/images/') &&
                    _isSupportedImageAsset(path),
              )
              .toList()
            ..sort();

      final videoAssets =
          manifestMap.keys
              .where(
                (path) =>
                    path.startsWith('assets/exercises/videos/') &&
                    _isSupportedVideoAsset(path),
              )
              .toList()
            ..sort();

      if (!mounted) {
        return;
      }

      setState(() {
        _exerciseImageAssets = imageAssets;
        _exerciseVideoAssets = videoAssets;
      });

      await _syncCurrentPhaseMedia();
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showMessage(
        'Exercise media not found yet. Add files in assets/exercises/.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingExerciseMedia = false;
        });
      }
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

  bool _isSupportedVideoAsset(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.webm') ||
        lower.endsWith('.m4v');
  }

  int _mediaSeedForPhase(WorkoutPhase phase) {
    final setNumber = phase.setNumber;
    if (setNumber != null && setNumber > 0) {
      return setNumber - 1;
    }
    if (phase.type == WorkoutPhaseType.cooldown) {
      return _controller.config.sets;
    }
    return _controller.phaseIndex.clamp(0, 1 << 20);
  }

  String? _pickMediaAssetForPhase(WorkoutPhase phase) {
    if (phase.type == WorkoutPhaseType.complete) {
      return null;
    }

    if (_isHiitCardio(_controller.config)) {
      final hiitExercise = _currentHiitExercise(phase)?.toLowerCase();
      final keywords = switch (phase.type) {
        WorkoutPhaseType.warmup => <String>['jog'],
        WorkoutPhaseType.work => _hiitKeywordsForExercise(hiitExercise),
        WorkoutPhaseType.rest => <String>['walk'],
        WorkoutPhaseType.cooldown => <String>['stretch'],
        WorkoutPhaseType.complete => <String>[],
      };

      if (keywords.isNotEmpty) {
        final matchingImage = _findAssetByKeywords(_exerciseImageAssets, keywords);
        if (matchingImage != null) {
          return matchingImage;
        }

        final matchingVideo = _findAssetByKeywords(_exerciseVideoAssets, keywords);
        if (matchingVideo != null) {
          return matchingVideo;
        }
      }
    }

    if (_isTabataCardio(_controller.config)) {
      final keywords = switch (phase.type) {
        WorkoutPhaseType.warmup => <String>['jog'],
        WorkoutPhaseType.work => <String>['sprint'],
        WorkoutPhaseType.rest => <String>['pause'],
        WorkoutPhaseType.cooldown => <String>['stretch'],
        WorkoutPhaseType.complete => <String>[],
      };

      if (keywords.isNotEmpty) {
        final matchingImage = _findAssetByKeywords(_exerciseImageAssets, keywords);
        if (matchingImage != null) {
          return matchingImage;
        }

        final matchingVideo = _findAssetByKeywords(_exerciseVideoAssets, keywords);
        if (matchingVideo != null) {
          return matchingVideo;
        }
      }
    }

    if (_isVo2MaxFourByFour(_controller.config)) {
      final keywords = switch (phase.type) {
        WorkoutPhaseType.warmup => <String>['run'],
        WorkoutPhaseType.work => <String>['sprint'],
        WorkoutPhaseType.rest => <String>['walk'],
        WorkoutPhaseType.cooldown => <String>['stretch'],
        WorkoutPhaseType.complete => <String>[],
      };

      if (keywords.isNotEmpty) {
        final matchingImage = _findAssetByKeywords(_exerciseImageAssets, keywords);
        if (matchingImage != null) {
          return matchingImage;
        }

        final matchingVideo = _findAssetByKeywords(_exerciseVideoAssets, keywords);
        if (matchingVideo != null) {
          return matchingVideo;
        }
      }
    }

    if (_isCalisthenicsRoutine(_controller.config) &&
        phase.type == WorkoutPhaseType.warmup) {
      final elapsedSeconds =
          (phase.durationSeconds - _controller.remainingSeconds).clamp(
            0,
            phase.durationSeconds,
          );
      final warmupIndex =
          (elapsedSeconds ~/ 30).clamp(0, _calisthenicsWarmupMoves.length - 1);
      final keywords = _calisthenicsWarmupAssetKeywords[warmupIndex];

      final matchingImage = _findAssetByKeywords(_exerciseImageAssets, keywords);
      if (matchingImage != null) {
        return matchingImage;
      }

      final matchingVideo = _findAssetByKeywords(_exerciseVideoAssets, keywords);
      if (matchingVideo != null) {
        return matchingVideo;
      }
    }

    final seed = _mediaSeedForPhase(phase);
    if (_exerciseVideoAssets.isNotEmpty) {
      return _exerciseVideoAssets[seed % _exerciseVideoAssets.length];
    }
    if (_exerciseImageAssets.isNotEmpty) {
      return _exerciseImageAssets[seed % _exerciseImageAssets.length];
    }
    return null;
  }

  String? _findAssetByKeywords(List<String> assets, List<String> keywords) {
    for (final asset in assets) {
      final baseName = _assetBaseName(asset).toLowerCase();
      final hasAllKeywords = keywords.every(baseName.contains);
      if (hasAllKeywords) {
        return asset;
      }
    }
    return null;
  }

  String _assetBaseName(String assetPath) {
    final lastSlash = assetPath.lastIndexOf('/');
    final fileName =
        lastSlash >= 0 ? assetPath.substring(lastSlash + 1) : assetPath;
    final lastDot = fileName.lastIndexOf('.');
    return lastDot > 0 ? fileName.substring(0, lastDot) : fileName;
  }

  Future<void> _syncCurrentPhaseMedia() async {
    if (!mounted) {
      return;
    }

    final selectedPath = _pickMediaAssetForPhase(_controller.currentPhase);
    if (selectedPath == _activeExerciseMediaPath) {
      return;
    }

    _activeExerciseMediaPath = selectedPath;
    if (selectedPath == null) {
      _disposeExerciseVideoController();
      if (mounted) {
        setState(() {});
      }
      return;
    }

    if (_isSupportedVideoAsset(selectedPath)) {
      await _setExerciseVideo(selectedPath);
    } else {
      _disposeExerciseVideoController();
      if (mounted) {
        setState(() {});
      }
    }

    _preloadNextPhaseMedia();
  }

  Future<void> _preloadNextPhaseMedia() async {
    if (!mounted) return;

    final nextPhase = _nextPhaseOrCurrent();
    if (nextPhase.type == WorkoutPhaseType.complete) {
      _disposeNextExerciseVideoController();
      return;
    }

    final nextPath = _pickMediaAssetForPhase(nextPhase);
    if (nextPath == _nextExerciseMediaPath) return;

    _disposeNextExerciseVideoController();
    _nextExerciseMediaPath = nextPath;

    if (nextPath != null && _isSupportedVideoAsset(nextPath)) {
      final controller = VideoPlayerController.asset(nextPath);
      try {
        await controller.initialize();
        await controller.setLooping(true);
        await controller.setVolume(0);
        if (mounted) {
          _nextExerciseVideoController = controller;
        } else {
          await controller.dispose();
        }
      } catch (_) {
        await controller.dispose();
      }
    }
  }

  Future<void> _setExerciseVideo(String assetPath) async {
    _disposeExerciseVideoController();
    final controller = VideoPlayerController.asset(assetPath);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _exerciseVideoController = controller;
      });
    } catch (_) {
      await controller.dispose();
      if (!mounted) {
        return;
      }

      setState(() {
        _exerciseVideoController = null;
      });
      _showMessage('Could not play this exercise video file.');
    }
  }

  void _disposeExerciseVideoController() {
    final controller = _exerciseVideoController;
    _exerciseVideoController = null;
    controller?.dispose();
  }

  void _disposeNextExerciseVideoController() {
    final controller = _nextExerciseVideoController;
    _nextExerciseVideoController = null;
    _nextExerciseMediaPath = null;
    controller?.dispose();
  }

  List<String> _buildExerciseNames() {
    final names = <String>[];
    for (final phase in _controller.timeline) {
      if (phase.type == WorkoutPhaseType.work) {
        final text = _phaseVoiceCueText(phase);
        if (text.isNotEmpty && !names.contains(text)) {
          names.add(text);
        }
      }
    }
    return names;
  }

  Future<void> _initializeFromSavedSettings() async {
    try {
      final saved = await _settingsService.load();
      if (!mounted) {
        return;
      }

      _controller.updateConfig(saved.config);
      await _audioEngine.initialize();

      _exerciseNames = _buildExerciseNames();
      if (_exerciseNames.isNotEmpty) {
        final fingerprint = WorkoutFingerprint(
          workoutId: saved.config.program.name,
          exerciseNames: _exerciseNames,
          exerciseDurations: _exerciseNames.map((_) => saved.config.workSeconds).toList(),
          restDurations: _exerciseNames.map((_) => saved.config.restSeconds).toList(),
          recoveryDurations: _exerciseNames.map((_) => saved.config.finalRestSeconds).toList(),
        );
        unawaited(_audioEngine.generateWorkoutVoice(
          fingerprint: fingerprint,
          exerciseNames: _exerciseNames,
        ));
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedIntensity = saved.config.intensity;
        _voiceCueEnabled = saved.voiceCueEnabled;
        _hapticCueEnabled = saved.hapticCueEnabled;
        _muteVoiceWhileMusicPlays = saved.muteVoiceWhileMusicPlays;
        _voiceCueVolume = saved.voiceCueVolume;
        _voiceCueRate = saved.voiceCueRate;
      });

      if (_launchConfig != null) {
        _controller.updateConfig(_launchConfig!);
        setState(() {
          _selectedIntensity = _launchConfig!.intensity;
        });
        _scheduleSettingsPersist();
      }
    } catch (e) {
      if (mounted) {
        _showMessage('Could not restore your saved settings. Using defaults.');
      }
    }
  }

  void _scheduleSettingsPersist() {
    _settingsPersistDebounce?.cancel();
    _settingsPersistDebounce = Timer(
      const Duration(milliseconds: 300),
      () async {
        try {
          final snapshot = AppSettings(
            config: _controller.config,
            voiceCueEnabled: _voiceCueEnabled,
            hapticCueEnabled: _hapticCueEnabled,
            muteVoiceWhileMusicPlays: _muteVoiceWhileMusicPlays,
            voiceCueVolume: _voiceCueVolume,
            voiceCueRate: _voiceCueRate,
          );
          await _settingsService.save(snapshot);
        } catch (e) {
          if (mounted) {
            _showMessage(
              'Saving settings failed. We will try again on your next change.',
            );
          }
        }
      },
    );
  }

  Future<void> _handleWorkoutCues() async {
    final phaseIndex = _controller.phaseIndex;
    final remaining = _controller.remainingSeconds;

    if (_controller.isRunning && phaseIndex != _lastObservedPhaseIndex) {
      _lastObservedPhaseIndex = phaseIndex;

      await _applyPhaseMusicProfile(_controller.currentPhase);

      if (!_controller.isComplete && phaseIndex < _controller.timeline.length) {
        if (_hapticCueEnabled) {
          await HapticFeedback.mediumImpact();
        }
        final phase = _controller.currentPhase;
        int exerciseIndex = 0;
        for (int i = 0; i < phaseIndex; i++) {
          if (_controller.timeline[i].type == WorkoutPhaseType.work) {
            exerciseIndex++;
          }
        }
        await _audioEngine.onExerciseChanged(exerciseIndex);
        if (phase.type == WorkoutPhaseType.rest) {
          _audioEngine.announceRest();
        } else {
          _audioEngine.announceExercise(
            _phaseVoiceCueText(phase),
            shouldSpeak: _voiceCueEnabled,
          );
        }
      }
    }

    if (_controller.isRunning && remaining != _lastAnnouncedSeconds) {
      _lastAnnouncedSeconds = remaining;
      final canSpeak = _voiceCueEnabled &&
          !(_muteVoiceWhileMusicPlays && _musicService.player.playing);

      if (remaining == 0) {
        if (_hapticCueEnabled) {
          await HapticFeedback.mediumImpact();
        }
        await _audioEngine.playTransitionAtZero();
      } else if (remaining >= 1 && remaining <= 5) {
        if (remaining <= 3 && _hapticCueEnabled) {
          await HapticFeedback.lightImpact();
        } else if (_hapticCueEnabled) {
          await HapticFeedback.selectionClick();
        }
        if (remaining <= 3) {
          await _audioEngine.playCountdownTick(remaining);
        }
        await _audioEngine.speakCount(remaining, shouldSpeak: canSpeak);
      }
    }

    if (_controller.isComplete && !_didAnnounceCompletion) {
      _didAnnounceCompletion = true;
      if (!_didRecordCompletionStats) {
        _didRecordCompletionStats = true;
        try {
          await _settingsService.recordWorkoutCompletion(
            _controller.totalWorkoutSeconds,
            config: _controller.config,
          );
          if (mounted && _isVo2MaxFourByFour(_controller.config)) {
            _showMessage(
              'VO2max complete: ${_controller.config.sets} intervals finished. Badge unlocked: Completed 4x4 VO2max session. Estimated VO2max gain +1.2%.',
            );
          }
        } catch (_) {}
      }
      if (_hapticCueEnabled) {
        await HapticFeedback.heavyImpact();
      }
      await _audioEngine.announceCompletion();
      return;
    }
  }

  Future<void> _applyPhaseMusicProfile(WorkoutPhase phase) async {
    final profile = _phaseMusicProfile(phase);
    if (!_autoPhaseMusicProfileEnabled || !_musicService.player.playing) {
      return;
    }

    try {
      await _musicService.setPlaybackSpeed(profile.playbackSpeed);
      if (mounted && _musicService.currentSong != null) {
        _showMessage('Music profile: ${profile.label} (${profile.bpmRange})');
      }
    } on MusicServiceException catch (e) {
      _showMessage(e.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _goBackToHome() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
      return;
    }
  }

  void _updateConfig({
    int? sets,
    int? work,
    int? rest,
    int? warmup,
    int? cooldown,
    WorkoutIntensity? intensity,
  }) {
    final next = _controller.config.copyWith(
      sets: sets,
      workSeconds: work,
      restSeconds: rest,
      warmupSeconds: warmup,
      cooldownSeconds: cooldown,
      intensity: intensity,
    );

    _controller.updateConfig(next);
    setState(() {
      _selectedIntensity = next.intensity;
    });
    _didRecordCompletionStats = false;
    _scheduleSettingsPersist();
  }

  WorkoutPhase _nextPhaseOrCurrent() {
    final timeline = _controller.timeline;
    final nextIndex = _controller.phaseIndex + 1;
    if (nextIndex >= 0 && nextIndex < timeline.length) {
      return timeline[nextIndex];
    }
    return _controller.currentPhase;
  }

  String _phaseHeaderSubtitle(WorkoutPhase phase) {
    if (_controller.isRunning) {
      return 'Workout in progress';
    }

    if (phase.type == WorkoutPhaseType.complete) {
      return 'Session complete';
    }

    return 'Build focus. Push limits. See results.';
  }

  String _phaseVoiceCueText(WorkoutPhase phase) {
    if (phase.type == WorkoutPhaseType.complete) {
      return 'Workout complete';
    }

    if (_isHiitCardio(_controller.config) && phase.type == WorkoutPhaseType.work) {
      return _currentHiitExercise(phase) ?? phase.label;
    }

    if (_isCalisthenicsRoutine(_controller.config) && phase.type == WorkoutPhaseType.work) {
      return _currentCalisthenicsExercise(phase) ?? phase.label;
    }

    return phase.label;
  }

  bool _isVo2MaxFourByFour(WorkoutConfig config) {
    return config.program == WorkoutProgram.vo2max ||
        (config.sets == 4 &&
            config.workSeconds == 240 &&
            config.restSeconds == 180 &&
            config.warmupSeconds == 600 &&
            config.cooldownSeconds >= 300);
  }

  bool _isHiitCardio(WorkoutConfig config) {
    return config.program == WorkoutProgram.hiitCardio ||
        (config.sets == 5 &&
            config.workSeconds == 40 &&
            config.restSeconds == 20 &&
            config.warmupSeconds == 180 &&
            config.cooldownSeconds == 120);
  }

  bool _isTabataCardio(WorkoutConfig config) {
    return config.program == WorkoutProgram.tabataCardio ||
        (config.sets == 8 &&
            config.workSeconds == 20 &&
            config.restSeconds == 10 &&
            config.warmupSeconds >= 120 &&
            config.warmupSeconds <= 180 &&
            config.cooldownSeconds >= 120 &&
            config.cooldownSeconds <= 180);
  }

  bool _isCalisthenicsRoutine(WorkoutConfig config) {
    return config.program == WorkoutProgram.calisthenics ||
        (config.sets == 12 &&
            config.workSeconds == 40 &&
            config.restSeconds == 20 &&
            config.warmupSeconds == 120 &&
            config.cooldownSeconds == 60 &&
            config.finalRestSeconds == 20);
  }

  String? _currentHiitExercise(WorkoutPhase phase) {
    if (phase.type != WorkoutPhaseType.work || phase.setNumber == null) {
      return null;
    }
    return _hiitWorkMoves[(phase.setNumber! - 1) % _hiitWorkMoves.length];
  }

  List<String> _hiitKeywordsForExercise(String? exercise) {
    if (exercise == null) {
      return const <String>['burpee'];
    }
    if (exercise.contains('mountain')) {
      return const <String>['mountain', 'climber'];
    }
    if (exercise.contains('squat')) {
      return const <String>['squat'];
    }
    if (exercise.contains('high knees')) {
      return const <String>['high', 'knees'];
    }
    if (exercise.contains('skater')) {
      return const <String>['skater'];
    }
    return const <String>['burpee'];
  }

  String? _currentCalisthenicsExercise(WorkoutPhase phase) {
    if (phase.type != WorkoutPhaseType.work || phase.setNumber == null) {
      return null;
    }
    return _calisthenicsMainMoves[(phase.setNumber! - 1) %
        _calisthenicsMainMoves.length];
  }

  _PhaseMusicProfile _phaseMusicProfile(WorkoutPhase phase) {
    if (_isHiitCardio(_controller.config)) {
      switch (phase.type) {
        case WorkoutPhaseType.warmup:
          return const _PhaseMusicProfile(
            label: 'Warm-up',
            bpmRange: '100-115 BPM',
            playbackSpeed: 0.95,
          );
        case WorkoutPhaseType.work:
          return const _PhaseMusicProfile(
            label: 'HIIT Work',
            bpmRange: '130-155 BPM',
            playbackSpeed: 1.12,
          );
        case WorkoutPhaseType.rest:
          return const _PhaseMusicProfile(
            label: 'HIIT Rest',
            bpmRange: '90-105 BPM',
            playbackSpeed: 0.9,
          );
        case WorkoutPhaseType.cooldown:
          return const _PhaseMusicProfile(
            label: 'Cool-down',
            bpmRange: '75-90 BPM',
            playbackSpeed: 0.85,
          );
        case WorkoutPhaseType.complete:
          return const _PhaseMusicProfile(
            label: 'Complete',
            bpmRange: '75-90 BPM',
            playbackSpeed: 0.85,
          );
      }
    }

    if (_isTabataCardio(_controller.config)) {
      switch (phase.type) {
        case WorkoutPhaseType.warmup:
          return const _PhaseMusicProfile(
            label: 'Warm-up',
            bpmRange: '100-115 BPM',
            playbackSpeed: 0.95,
          );
        case WorkoutPhaseType.work:
          return const _PhaseMusicProfile(
            label: 'Tabata Work',
            bpmRange: '140-165 BPM',
            playbackSpeed: 1.2,
          );
        case WorkoutPhaseType.rest:
          return const _PhaseMusicProfile(
            label: 'Tabata Rest',
            bpmRange: '90-105 BPM',
            playbackSpeed: 0.9,
          );
        case WorkoutPhaseType.cooldown:
          return const _PhaseMusicProfile(
            label: 'Cool-down',
            bpmRange: '75-90 BPM',
            playbackSpeed: 0.85,
          );
        case WorkoutPhaseType.complete:
          return const _PhaseMusicProfile(
            label: 'Complete',
            bpmRange: '75-90 BPM',
            playbackSpeed: 0.85,
          );
      }
    }

    if (_isVo2MaxFourByFour(_controller.config)) {
      switch (phase.type) {
        case WorkoutPhaseType.warmup:
          return const _PhaseMusicProfile(
            label: 'Warm-up',
            bpmRange: '90-100 BPM',
            playbackSpeed: 0.9,
          );
        case WorkoutPhaseType.work:
          return const _PhaseMusicProfile(
            label: 'High Intensity',
            bpmRange: '130-150 BPM',
            playbackSpeed: 1.15,
          );
        case WorkoutPhaseType.rest:
          return const _PhaseMusicProfile(
            label: 'Recovery',
            bpmRange: '90-100 BPM',
            playbackSpeed: 0.9,
          );
        case WorkoutPhaseType.cooldown:
          return const _PhaseMusicProfile(
            label: 'Cool-down',
            bpmRange: '70-80 BPM',
            playbackSpeed: 0.8,
          );
        case WorkoutPhaseType.complete:
          return const _PhaseMusicProfile(
            label: 'Complete',
            bpmRange: '70-80 BPM',
            playbackSpeed: 0.8,
          );
      }
    }

    switch (phase.type) {
      case WorkoutPhaseType.warmup:
        return const _PhaseMusicProfile(
          label: 'Warm-up',
          bpmRange: '100-115 BPM',
          playbackSpeed: 0.95,
        );
      case WorkoutPhaseType.work:
        return const _PhaseMusicProfile(
          label: 'Work',
          bpmRange: '120-140 BPM',
          playbackSpeed: 1.05,
        );
      case WorkoutPhaseType.rest:
        return const _PhaseMusicProfile(
          label: 'Rest',
          bpmRange: '90-105 BPM',
          playbackSpeed: 0.9,
        );
      case WorkoutPhaseType.cooldown:
        return const _PhaseMusicProfile(
          label: 'Cool-down',
          bpmRange: '75-90 BPM',
          playbackSpeed: 0.85,
        );
      case WorkoutPhaseType.complete:
        return const _PhaseMusicProfile(
          label: 'Complete',
          bpmRange: '75-90 BPM',
          playbackSpeed: 0.85,
        );
    }
  }

  List<Color> _phasePalette(WorkoutPhaseType type) {
    if (_isHiitCardio(_controller.config) || _isTabataCardio(_controller.config) || _isVo2MaxFourByFour(_controller.config)) {
      switch (type) {
        case WorkoutPhaseType.warmup:
          return const [Color(0xFF1B6B3A), Color(0xFF6BCB77)];
        case WorkoutPhaseType.work:
          return const [Color(0xFF8B1A2A), Color(0xFFFF5A5F)];
        case WorkoutPhaseType.rest:
          return const [Color(0xFF0E4D6B), Color(0xFF2AB7CA)];
        case WorkoutPhaseType.cooldown:
          return const [Color(0xFF1B6B3A), Color(0xFF6BCB77)];
        case WorkoutPhaseType.complete:
          return const [Color(0xFF333333), Color(0xFF666666)];
      }
    }

    switch (type) {
      case WorkoutPhaseType.warmup:
        return const [Color(0xFF7A4A0E), Color(0xFFF7A531)];
      case WorkoutPhaseType.work:
        return const [Color(0xFF8B1A2A), Color(0xFFFF5A5F)];
      case WorkoutPhaseType.rest:
        return const [Color(0xFF0E4D6B), Color(0xFF2AB7CA)];
      case WorkoutPhaseType.cooldown:
        return const [Color(0xFF1B6B3A), Color(0xFF6BCB77)];
      case WorkoutPhaseType.complete:
        return const [Color(0xFF333333), Color(0xFF666666)];
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final phase = _controller.currentPhase;
        final palette = _phasePalette(phase.type);
        final nextPhase = _nextPhaseOrCurrent();

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
                  child: GlowBlob(color: palette.last.withValues(alpha: 0.45)),
                ),
                SafeArea(
                  child: widget.timerMode == TimerMode.home
                      ? _buildHomeLayout(context, phase, palette, nextPhase)
                      : _buildWorkoutLayout(context, phase, palette, nextPhase),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHomeLayout(
    BuildContext context,
    WorkoutPhase phase,
    List<Color> palette,
    WorkoutPhase nextPhase,
  ) {
    return HomeTimerLayout(
      phase: phase,
      palette: palette,
      isRunning: _controller.isRunning,
      phaseProgress: _controller.phaseProgress,
      remainingSeconds: _controller.remainingSeconds,
      pulseScale: _pulseController.value,
      totalProgress: _controller.totalProgress,
      elapsedSeconds: _controller.elapsedWorkoutSeconds,
      totalWorkoutSeconds: _controller.totalWorkoutSeconds,
      timeline: _controller.timeline,
      phaseIndex: _controller.phaseIndex,
      currentRemainingSeconds: _controller.remainingSeconds,
      nextPhase: nextPhase,
      config: _controller.config,
      onStartPause: () {
        if (_controller.isRunning) {
          _controller.pause();
          WakelockPlus.disable();
        } else {
          final wasNotStarted = !_hasStarted;
          _hasStarted = true;
          _controller.start();
          WakelockPlus.enable();
          if (wasNotStarted) {
            HapticFeedback.heavyImpact();
          }
        }
      },
      onReset: () {
        _didRecordCompletionStats = false;
        _hasStarted = false;
        _controller.stop(reset: true);
        WakelockPlus.disable();
      },
      onSkip: _controller.skipPhase,
      headerSubtitle: _phaseHeaderSubtitle(phase),
      onBackPressed: _goBackToHome,
      canPop: Navigator.of(context).canPop(),
      customizationWidget: _CustomizationToggleCard(
        expanded: _showCustomizationPanel,
        onTap: () {
          setState(() {
            _showCustomizationPanel = !_showCustomizationPanel;
          });
        },
      ),
      configPanelWidget: _ConfigPanel(
        config: _controller.config,
        selectedIntensity: _selectedIntensity,
        onChanged: _updateConfig,
        voiceCueEnabled: _voiceCueEnabled,
        hapticCueEnabled: _hapticCueEnabled,
        onVoiceCueChanged: (value) {
          setState(() {
            _voiceCueEnabled = value;
          });
          if (!value) {
            _audioEngine.stop();
          }
          _scheduleSettingsPersist();
        },
        onHapticCueChanged: (value) {
          setState(() {
            _hapticCueEnabled = value;
          });
          _scheduleSettingsPersist();
        },
        muteVoiceWhileMusicPlays: _muteVoiceWhileMusicPlays,
        onMuteVoiceWhileMusicChanged: (value) {
          setState(() {
            _muteVoiceWhileMusicPlays = value;
          });
          if (value && _musicService.player.playing) {
            _audioEngine.stop();
          }
          _scheduleSettingsPersist();
        },
        voiceCueVolume: _voiceCueVolume,
        onVoiceCueVolumeChanged: (value) async {
          setState(() {
            _voiceCueVolume = value;
          });
          _scheduleSettingsPersist();
        },
        voiceCueRate: _voiceCueRate,
        onVoiceCueRateChanged: (value) async {
          setState(() {
            _voiceCueRate = value;
          });
          _scheduleSettingsPersist();
        },
        audioEngine: _audioEngine,
        settings: AppSettings.defaults(),
        currentFingerprint: _audioEngine.currentFingerprint,
        currentExerciseNames: _exerciseNames,
      ),
      showCustomizationPanel: _showCustomizationPanel,
      tempoPanelWidget: _PhaseTempoPanel(
        profile: _phaseMusicProfile(phase),
        autoProfileEnabled: _autoPhaseMusicProfileEnabled,
        isMusicPlaying: _musicService.player.playing,
        playbackSpeed: _musicService.playbackSpeed,
        onAutoProfileChanged: (value) async {
          setState(() {
            _autoPhaseMusicProfileEnabled = value;
          });
          if (value && _musicService.player.playing) {
            await _applyPhaseMusicProfile(phase);
          }
        },
      ),
      guideCards: [
        if (_isHiitCardio(_controller.config)) ...[
          const SizedBox(height: 14),
          const _HiitGuideCard(),
        ],
        if (_isVo2MaxFourByFour(_controller.config)) ...[
          const SizedBox(height: 14),
          const _Vo2MaxGuideCard(),
        ],
        if (_isTabataCardio(_controller.config)) ...[
          const SizedBox(height: 14),
          const _TabataGuideCard(),
        ],
        if (_isCalisthenicsRoutine(_controller.config)) ...[
          const SizedBox(height: 14),
          _CalisthenicsGuideCard(
            phase: phase,
            currentExercise: _currentCalisthenicsExercise(phase),
          ),
        ],
      ],
    );
  }

  Widget _buildWorkoutLayout(
    BuildContext context,
    WorkoutPhase phase,
    List<Color> palette,
    WorkoutPhase nextPhase,
  ) {
    if (_controller.isComplete && _hasStarted) {
      return _buildCompletionScreen(context, palette);
    }

    final isPaused = !_controller.isRunning && _hasStarted;

    return WorkoutTimerLayout(
      phase: phase,
      palette: palette,
      isRunning: _controller.isRunning,
      isComplete: _controller.isComplete,
      phaseProgress: _controller.phaseProgress,
      remainingSeconds: _controller.remainingSeconds,
      totalProgress: _controller.totalProgress,
      elapsedSeconds: _controller.elapsedWorkoutSeconds,
      totalWorkoutSeconds: _controller.totalWorkoutSeconds,
      timeline: _controller.timeline,
      phaseIndex: _controller.phaseIndex,
      currentRemainingSeconds: _controller.remainingSeconds,
      nextPhase: nextPhase,
      mediaPath: _activeExerciseMediaPath,
      videoController: _exerciseVideoController,
      loadingMedia: _loadingExerciseMedia,
      isPaused: isPaused,
      onStartPause: () {
        if (_controller.isRunning) {
          _controller.pause();
          WakelockPlus.disable();
        } else {
          final wasNotStarted = !_hasStarted;
          _hasStarted = true;
          _controller.start();
          WakelockPlus.enable();
          if (wasNotStarted) {
            HapticFeedback.heavyImpact();
          }
        }
      },
      onReset: () {
        _didRecordCompletionStats = false;
        _hasStarted = false;
        _controller.stop(reset: true);
        WakelockPlus.disable();
      },
      onSkip: _controller.skipPhase,
      onResume: () {
        _controller.start();
        WakelockPlus.enable();
      },
      onRestart: () {
        _hasStarted = false;
        _controller.stop(reset: true);
        WakelockPlus.disable();
      },
      onQuit: () {
        _hasStarted = false;
        _controller.stop(reset: true);
        WakelockPlus.disable();
        _goBackToHome();
      },
      headerTitle: 'Workout Player',
      headerSubtitle: _phaseHeaderSubtitle(phase),
      onBackPressed: _goBackToHome,
      canPop: Navigator.of(context).canPop(),
    );
  }

  Widget _buildCompletionScreen(BuildContext context, List<Color> palette) {
    final totalMinutes = _controller.totalWorkoutSeconds ~/ 60;
    final totalSecs = _controller.totalWorkoutSeconds % 60;
    final estimatedCalories = (_controller.totalWorkoutSeconds * 0.15).round();
    final completedExercises = _controller.timeline
        .where((p) => p.type == WorkoutPhaseType.work)
        .length;

    return Center(
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
                onPressed: () {
                  _hasStarted = false;
                  _controller.stop(reset: true);
                  _goBackToHome();
                },
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

class _PhaseMusicProfile {
  const _PhaseMusicProfile({
    required this.label,
    required this.bpmRange,
    required this.playbackSpeed,
  });

  final String label;
  final String bpmRange;
  final double playbackSpeed;
}



class _CalisthenicsGuideCard extends StatelessWidget {
  const _CalisthenicsGuideCard({
    required this.phase,
    required this.currentExercise,
  });

  final WorkoutPhase phase;
  final String? currentExercise;

  @override
  Widget build(BuildContext context) {
    final focusText = switch (phase.type) {
      WorkoutPhaseType.warmup =>
        'Warm-up flow: wake up joints, raise heart rate, stay light.',
      WorkoutPhaseType.work =>
        currentExercise == null
            ? 'Main circuit: 40s work, 20s rest.'
            : 'Current focus: $currentExercise for 40 seconds.',
      WorkoutPhaseType.rest =>
        'Use the 20-second reset to control breathing and set up the next move.',
      WorkoutPhaseType.cooldown =>
        'Slow everything down and let the heart rate come back under control.',
      WorkoutPhaseType.complete => 'Routine complete. Walk it off and recover.',
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF6BCB77).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center_rounded, color: Color(0xFF6BCB77), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  '15-Min Calisthenics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            '2 min warm-up, 12 min circuit, 1 min cool-down',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          Text(
            focusText,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 12),
          const _GuideSection(
            title: 'Warm-up',
            items: _calisthenicsWarmupMoves,
          ),
          const SizedBox(height: 10),
          const _GuideSection(
            title: 'Main Circuit',
            items: _calisthenicsMainMoves,
          ),
          const SizedBox(height: 10),
          const _GuideSection(
            title: 'Cool-down',
            items: _calisthenicsCooldownMoves,
          ),
        ],
      ),
    );
  }
}

class _Vo2MaxGuideCard extends StatelessWidget {
  const _Vo2MaxGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2AB7CA).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.monitor_heart_rounded, color: Color(0xFF2AB7CA), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'VO2max 4x4 Structure',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Total session time: about 40-45 minutes',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 14),
          _Vo2PhaseRow(
            icon: Icons.directions_run_rounded,
            phase: 'Follow-up',
            duration: '10 min',
            intensity: '60-70% HRmax',
            cue: 'Easy pace with light cardio and dynamic stretches',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Interval 1',
            duration: '4 min',
            intensity: '85-95% HRmax',
            cue: 'Push hard',
          ),
          _Vo2PhaseRow(
            icon: Icons.directions_walk_rounded,
            phase: 'Follow-up 1',
            duration: '3 min',
            intensity: 'Easy pace',
            cue: 'Recover',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Interval 2',
            duration: '4 min',
            intensity: '85-95% HRmax',
            cue: 'Push hard',
          ),
          _Vo2PhaseRow(
            icon: Icons.directions_walk_rounded,
            phase: 'Follow-up 2',
            duration: '3 min',
            intensity: 'Easy pace',
            cue: 'Recover',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Interval 3',
            duration: '4 min',
            intensity: '85-95% HRmax',
            cue: 'Push hard',
          ),
          _Vo2PhaseRow(
            icon: Icons.directions_walk_rounded,
            phase: 'Follow-up 3',
            duration: '3 min',
            intensity: 'Easy pace',
            cue: 'Recover',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Interval 4',
            duration: '4 min',
            intensity: '85-95% HRmax',
            cue: 'Push hard',
          ),
          _Vo2PhaseRow(
            icon: Icons.directions_walk_rounded,
            phase: 'Follow-up 4',
            duration: '3 min',
            intensity: 'Easy pace',
            cue: 'Recover',
          ),
          _Vo2PhaseRow(
            icon: Icons.self_improvement_rounded,
            phase: 'Cool-down',
            duration: '5-10 min',
            intensity: 'Around 60% HRmax',
            cue: 'Stretch and bring heart rate down',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _HiitGuideCard extends StatelessWidget {
  const _HiitGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5A5F).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.bolt_rounded, color: Color(0xFFFF5A5F), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'HIIT Cardio Protocol',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Duration: 15 minutes',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          SizedBox(height: 12),
          _Vo2PhaseRow(
            icon: Icons.directions_walk_rounded,
            phase: 'Warm-up',
            duration: '3 min',
            intensity: 'Easy pace',
            cue: 'March in place, jumping jacks, high knees (easy)',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Work',
            duration: '40 sec',
            intensity: 'Intermediate',
            cue: 'Burpees, climbers, jump squats, high knees, or skater jumps',
          ),
          _Vo2PhaseRow(
            icon: Icons.pause_circle_rounded,
            phase: 'Rest',
            duration: '20 sec',
            intensity: 'Recovery',
            cue: 'Walk in place and deep breathing',
          ),
          _Vo2PhaseRow(
            icon: Icons.repeat_rounded,
            phase: 'Repeat cycle',
            duration: '5 rounds (10 min)',
            intensity: 'Cardio and endurance focus',
            cue: 'Display one move each round or let user choose',
          ),
          _Vo2PhaseRow(
            icon: Icons.self_improvement_rounded,
            phase: 'Cool-down',
            duration: '2 min',
            intensity: 'Easy',
            cue: 'Walk slowly and stretch legs and hips',
            isLast: true,
          ),
          SizedBox(height: 10),
          _GuideSection(title: 'Work Moves', items: _hiitWorkMoves),
          SizedBox(height: 10),
          Text(
            'Estimated calories: 120-220 kcal (depends on body weight and intensity)',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TabataGuideCard extends StatelessWidget {
  const _TabataGuideCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF2AB7CA).withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.timer_rounded, color: Color(0xFF2AB7CA), size: 18),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Tabata Cardio Protocol',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Total session time: about 10 minutes',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          SizedBox(height: 12),
          _Vo2PhaseRow(
            icon: Icons.directions_run_rounded,
            phase: 'Warm-up',
            duration: '2-3 min',
            intensity: 'Easy jog or dynamic moves',
            cue: 'Jogging icon or light cardio GIF',
          ),
          _Vo2PhaseRow(
            icon: Icons.bolt_rounded,
            phase: 'Work interval',
            duration: '20 sec',
            intensity: 'All-out effort',
            cue: 'Red block + sprint icon (Go hard!)',
          ),
          _Vo2PhaseRow(
            icon: Icons.pause_circle_rounded,
            phase: 'Rest interval',
            duration: '10 sec',
            intensity: 'Passive or light movement',
            cue: 'Blue block + pause icon (Rest now.)',
          ),
          _Vo2PhaseRow(
            icon: Icons.repeat_rounded,
            phase: 'Repeat cycle',
            duration: '8 rounds (4 min total)',
            intensity: 'Alternating work and rest',
            cue: 'Timeline alternates red and blue blocks',
          ),
          _Vo2PhaseRow(
            icon: Icons.self_improvement_rounded,
            phase: 'Cool-down',
            duration: '2-3 min',
            intensity: 'Stretching and slow walk',
            cue: 'Stretch icon or yoga GIF',
            isLast: true,
          ),
        ],
      ),
    );
  }
}

class _Vo2PhaseRow extends StatelessWidget {
  const _Vo2PhaseRow({
    required this.icon,
    required this.phase,
    required this.duration,
    required this.intensity,
    required this.cue,
    this.isLast = false,
  });

  final IconData icon;
  final String phase;
  final String duration;
  final String intensity;
  final String cue;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$phase \u2022 $duration',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  intensity,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 1),
                Text(
                  cue,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: items
              .map(
                (item) => Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Text(
                    item,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _CustomizationToggleCard extends StatelessWidget {
  const _CustomizationToggleCard({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune_rounded, color: Color(0xFFFF8A1E), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Customize Timing',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    expanded ? 'Collapse options' : 'Adjust sets, work, rest & more',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: Colors.white70,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ConfigPanel extends StatelessWidget {
  const _ConfigPanel({
    required this.config,
    required this.selectedIntensity,
    required this.onChanged,
    required this.voiceCueEnabled,
    required this.hapticCueEnabled,
    required this.onVoiceCueChanged,
    required this.onHapticCueChanged,
    required this.muteVoiceWhileMusicPlays,
    required this.onMuteVoiceWhileMusicChanged,
    required this.voiceCueVolume,
    required this.onVoiceCueVolumeChanged,
    required this.voiceCueRate,
    required this.onVoiceCueRateChanged,
    required this.audioEngine,
    required this.settings,
    required this.currentFingerprint,
    required this.currentExerciseNames,
  });

  final WorkoutConfig config;
  final WorkoutIntensity selectedIntensity;
  final void Function({
    int? sets,
    int? work,
    int? rest,
    int? warmup,
    int? cooldown,
    WorkoutIntensity? intensity,
  }) onChanged;
  final bool voiceCueEnabled;
  final bool hapticCueEnabled;
  final ValueChanged<bool> onVoiceCueChanged;
  final ValueChanged<bool> onHapticCueChanged;
  final bool muteVoiceWhileMusicPlays;
  final ValueChanged<bool> onMuteVoiceWhileMusicChanged;
  final double voiceCueVolume;
  final ValueChanged<double> onVoiceCueVolumeChanged;
  final double voiceCueRate;
  final ValueChanged<double> onVoiceCueRateChanged;
  final AudioEngine audioEngine;
  final AppSettings settings;
  final String? currentFingerprint;
  final List<String> currentExerciseNames;

  @override
  Widget build(BuildContext context) {
    const double setsMax = 50.0;
    final double workMax = config.workSeconds > 240
        ? config.workSeconds.toDouble()
        : 240.0;
    final double restMax = config.restSeconds > 180
        ? config.restSeconds.toDouble()
        : 180.0;
    final double warmupMax = config.warmupSeconds > 600
        ? config.warmupSeconds.toDouble()
        : 600.0;
    final double cooldownMax = config.cooldownSeconds > 300
        ? config.cooldownSeconds.toDouble()
        : 300.0;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Session Builder',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          _LabeledSlider(
            label: 'Sets: ${config.sets}',
            value: config.sets.toDouble(),
            min: 1,
            max: setsMax,
            divisions: setsMax.round() - 1,
            onChanged: (v) => onChanged(sets: v.round()),
          ),
          _LabeledSlider(
            label: 'Work: ${config.workSeconds}s',
            value: config.workSeconds.toDouble(),
            min: 10,
            max: workMax,
            divisions: ((workMax - 10) / 5).round(),
            onChanged: (v) => onChanged(work: v.round()),
          ),
          _LabeledSlider(
            label: 'Rest: ${config.restSeconds}s',
            value: config.restSeconds.toDouble(),
            min: 5,
            max: restMax,
            divisions: ((restMax - 5) / 5).round(),
            onChanged: (v) => onChanged(rest: v.round()),
          ),
          _LabeledSlider(
            label: 'Warmup: ${config.warmupSeconds}s',
            value: config.warmupSeconds.toDouble(),
            min: 0,
            max: warmupMax,
            divisions: (warmupMax / 5).round(),
            onChanged: (v) => onChanged(warmup: v.round()),
          ),
          _LabeledSlider(
            label: 'Cooldown: ${config.cooldownSeconds}s',
            value: config.cooldownSeconds.toDouble(),
            min: 0,
            max: cooldownMax,
            divisions: (cooldownMax / 5).round(),
            onChanged: (v) => onChanged(cooldown: v.round()),
          ),
          const SizedBox(height: 6),
          const Text('Intensity', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: WorkoutIntensity.values.map((intensity) {
              final selected = intensity == selectedIntensity;
              return ChoiceChip(
                label: Text(
                  intensity.name.toUpperCase(),
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                selected: selected,
                onSelected: (_) => onChanged(intensity: intensity),
                selectedColor: Colors.white,
                backgroundColor: Colors.white12,
                side: const BorderSide(color: Colors.white24),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _CueToggleTile(
                  label: 'Voice Cue',
                  value: voiceCueEnabled,
                  icon: Icons.record_voice_over_rounded,
                  onChanged: onVoiceCueChanged,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _CueToggleTile(
                  label: 'Haptic Cue',
                  value: hapticCueEnabled,
                  icon: Icons.vibration_rounded,
                  onChanged: onHapticCueChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _CueToggleTile(
            label: 'Mute Voice While Music Plays',
            value: muteVoiceWhileMusicPlays,
            icon: Icons.volume_off_rounded,
            onChanged: onMuteVoiceWhileMusicChanged,
          ),
          const SizedBox(height: 10),
          _LabeledSlider(
            label: 'Voice Volume: ${(voiceCueVolume * 100).round()}%',
            value: voiceCueVolume,
            min: 0,
            max: 1,
            divisions: 10,
            onChanged: onVoiceCueVolumeChanged,
          ),
          _LabeledSlider(
            label: 'Voice Speed: ${voiceCueRate.toStringAsFixed(2)}x',
            value: voiceCueRate,
            min: 0.2,
            max: 0.8,
            divisions: 12,
            onChanged: onVoiceCueRateChanged,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AudioSettingsPage(
                      audioEngine: audioEngine,
                      settings: settings,
                      onSettingsChanged: () {},
                      currentFingerprint: currentFingerprint,
                      currentExerciseNames: currentExerciseNames,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Audio Settings'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF22C55E),
                side: const BorderSide(color: Color(0xFF22C55E)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final safeValue = value.clamp(min, max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
            activeTrackColor: const Color(0xFFFF8A1E),
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: safeValue,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

class _CueToggleTile extends StatelessWidget {
  const _CueToggleTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final IconData icon;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 12,
                letterSpacing: 0.2,
              ),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}







class _PhaseTempoPanel extends StatelessWidget {
  const _PhaseTempoPanel({
    required this.profile,
    required this.autoProfileEnabled,
    required this.isMusicPlaying,
    required this.playbackSpeed,
    required this.onAutoProfileChanged,
  });

  final _PhaseMusicProfile profile;
  final bool autoProfileEnabled;
  final bool isMusicPlaying;
  final double playbackSpeed;
  final ValueChanged<bool> onAutoProfileChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded, color: Colors.orangeAccent),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Phase Music Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => onAutoProfileChanged(!autoProfileEnabled),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: autoProfileEnabled
                        ? const Color(0xFFFF8A1E).withValues(alpha: 0.16)
                        : Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: autoProfileEnabled
                          ? const Color(0xFFFF8A1E).withValues(alpha: 0.35)
                          : Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: Text(
                    autoProfileEnabled ? 'Active' : 'Off',
                    style: TextStyle(
                      color: autoProfileEnabled
                          ? const Color(0xFFFFB15C)
                          : Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${profile.label}: ${profile.bpmRange}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 28,
            alignment: Alignment.bottomCenter,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(18, (index) {
                final height = 5.0 + ((index % 5) * 4.0);
                final active = index.isEven;
                return Container(
                  width: 6,
                  height: height,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFFFF8A1E)
                        : Colors.white.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(99),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isMusicPlaying
                ? 'Auto speed ${playbackSpeed.toStringAsFixed(2)}x'
                : 'Pick and play a track to apply tempo profiles automatically.',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

