import 'dart:async';
import 'dart:collection';

import 'package:my_app/models/cached_workout_info.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/services/gemini_voice_service.dart';
import 'package:my_app/services/music_service.dart';
import 'package:my_app/services/sfx_service.dart';

class _AudioTask {
  _AudioTask(this.execute);
  final Future<void> Function() execute;
}

class _AudioQueue {
  final Queue<_AudioTask> _queue = Queue();
  bool _isPlaying = false;
  bool _cancelled = false;

  Future<void> enqueue(Future<void> Function() task) async {
    if (_cancelled) return;
    _queue.add(_AudioTask(task));
    if (!_isPlaying) _processQueue();
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty || _cancelled) {
      _isPlaying = false;
      return;
    }
    _isPlaying = true;
    final task = _queue.removeFirst();
    await task.execute();
    _processQueue();
  }

  void clear() {
    _queue.clear();
    _isPlaying = false;
    _cancelled = true;
  }

  void reset() {
    _cancelled = false;
  }
}

class AudioEngine {
  AudioEngine({
    required GeminiVoiceService voice,
    required SfxService sfx,
    MusicService? music,
  })  : _voice = voice,
        _sfx = sfx,
        _music = music;

  final GeminiVoiceService _voice;
  final SfxService _sfx;
  final MusicService? _music;
  final _AudioQueue _voiceQueue = _AudioQueue();

  String? _currentFingerprint;
  bool _isPreloaded = false;
  bool _musicDuckingEnabled = true;
  bool _countdownBeepsEnabled = true;
  bool _transitionSoundEnabled = true;
  int _currentExerciseIndex = -1;

  String _exerciseClipKey(String name) =>
      'exercise_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  bool get isPreloaded => _isPreloaded;
  String? get currentFingerprint => _currentFingerprint;

  Future<void> initialize() async {
    await _voice.initialize();
    await _sfx.initialize();
  }

  void updateSettings({
    bool? countdownBeepsEnabled,
    bool? transitionSoundEnabled,
    bool? musicDuckingEnabled,
  }) {
    if (countdownBeepsEnabled != null) _countdownBeepsEnabled = countdownBeepsEnabled;
    if (transitionSoundEnabled != null) _transitionSoundEnabled = transitionSoundEnabled;
    if (musicDuckingEnabled != null) _musicDuckingEnabled = musicDuckingEnabled;
  }

  // --- Preloading ---

  Future<void> preloadWorkout(WorkoutFingerprint fingerprint) async {
    final fp = fingerprint.compute();
    _currentFingerprint = fp;

    if (await _voice.cacheExists(fp)) {
      await _voice.preloadClips(fp, [
        ...GeminiVoiceService.standardPrompts.keys,
        'workout_started',
        'workout_complete',
      ]);
      _isPreloaded = true;
    } else {
      _isPreloaded = false;
    }
  }

  Future<void> generateWorkoutVoice({
    required WorkoutFingerprint fingerprint,
    required List<String> exerciseNames,
    String? workoutName,
    void Function(double progress)? onProgress,
  }) async {
    final fp = fingerprint.compute();
    _currentFingerprint = fp;

    await _voice.generateAll(
      fingerprint: fp,
      exerciseNames: exerciseNames,
      workoutName: workoutName,
      onProgress: onProgress != null ? (p) { onProgress(p); return false; } : null,
    );

    await _voice.preloadClips(fp, [
      ...GeminiVoiceService.standardPrompts.keys,
      ...exerciseNames.map((n) => _exerciseClipKey(n)),
    ]);
    _isPreloaded = true;
  }

  Future<void> setExerciseList(List<String> exerciseNames) async {
    _currentExerciseIndex = -1;

    final fp = _currentFingerprint;
    if (fp == null || !await _voice.cacheExists(fp)) {
      _isPreloaded = false;
      return;
    }

    final clipsToLoad = <String>[
      ...GeminiVoiceService.standardPrompts.keys,
      ...exerciseNames.map((n) => _exerciseClipKey(n)),
    ];

    await _voice.preloadClips(fp, clipsToLoad);
    _isPreloaded = true;
  }

  Future<void> onExerciseChanged(int currentIndex) async {
    if (currentIndex == _currentExerciseIndex) return;
    _currentExerciseIndex = currentIndex;
  }

  // --- Voice Announcements ---

  Future<void> _speakClip(String clipName, {String? fallbackText}) async {
    final fp = _currentFingerprint;
    if (fp == null) return;

    await _voiceQueue.enqueue(() async {
      await _duckMusic();
      bool played = false;
      if (_isPreloaded) {
        await _voice.playPreloadedClip(clipName);
        played = true;
      } else {
        played = await _voice.playClip(fp, clipName);
      }
      if (!played) {
        final text = fallbackText ??
            GeminiVoiceService.standardPrompts[clipName] ??
            clipName;
        await _voice.speakFallback(text);
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _unduckMusic();
    });
  }

  void _fireClip(String clipName, {String? fallbackText}) {
    final fp = _currentFingerprint;
    if (fp == null) return;
    unawaited(() async {
      await _duckMusic();
      bool played = false;
      if (_isPreloaded) {
        played = await _voice.playPreloadedClip(clipName);
      }
      if (!played) {
        played = await _voice.playClip(fp, clipName);
        if (!played) {
          final text = fallbackText ??
              GeminiVoiceService.standardPrompts[clipName] ??
              clipName;
          await _voice.speakFallback(text);
        }
      }
      await Future.delayed(const Duration(milliseconds: 300));
      await _unduckMusic();
    }());
  }

  Future<void> announceWorkoutStarted() => _speakClip('workout_started');
  Future<void> announceWarmup() => _speakClip('warmup');
  Future<void> announceBegin() => _speakClip('begin');
  Future<void> announceWork() => _speakClip('work');
  void announceRest() => _fireClip('rest');
  Future<void> announceRecover() => _speakClip('recover');
  Future<void> announceHalfwayThere() => _speakClip('halfway_there');
  Future<void> announceLastRound() => _speakClip('last_round');
  Future<void> announceCompletion() => _speakClip('workout_complete');
  Future<void> announceGreatJob() => _speakClip('great_job');
  Future<void> announceKeepGoing() => _speakClip('keep_going');
  Future<void> announceExcellentWork() => _speakClip('excellent_work');

  void announceExercise(String name, {bool shouldSpeak = true}) {
    if (!shouldSpeak) return;
    final clipKey = 'exercise_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    _fireClip(clipKey, fallbackText: '$name.');
  }

  Future<void> announcePhase(String label, {bool shouldSpeak = true}) async {
    if (!shouldSpeak) return;
    announceExercise(label, shouldSpeak: shouldSpeak);
  }

  Future<void> speakCount(int seconds, {bool shouldSpeak = true}) async {
    if (!shouldSpeak || seconds < 1 || seconds > 5) return;
    const names = {5: 'Five', 4: 'Four', 3: 'Three', 2: 'Two', 1: 'One'};
    final text = names[seconds];
    if (text == null) return;
    unawaited(_voice.speakFallback(text));
  }

  Future<void> playTransitionAtZero() async {
    await _sfx.playCountdownFinalBeep();
    await _sfx.playTransitionWhoosh();
  }

  // --- Sound Effects ---

  Future<void> playCountdownTick(int secondsRemaining) async {
    if (!_countdownBeepsEnabled) return;
    await _sfx.playCountdownTick(secondsRemaining);
  }

  Future<void> playCountdownFinalBeep() async {
    if (!_countdownBeepsEnabled) return;
    await _sfx.playCountdownFinalBeep();
  }

  Future<void> playTransitionWhoosh() async {
    if (!_transitionSoundEnabled) return;
    await _sfx.playTransitionWhoosh();
  }

  Future<void> playVictorySound() async {
    if (!_transitionSoundEnabled) return;
    await _sfx.playVictorySound();
  }

  Future<void> playPhaseCompletionBeep() async {
    // API compatibility - no-op
  }

  Future<void> playWorkoutCompletionBeep() async {
    // API compatibility - no-op
  }

  // --- Music Ducking ---

  Future<void> _duckMusic() async {
    if (!_musicDuckingEnabled) return;
    final music = _music;
    if (music == null || !music.player.playing) return;
    if (music.isDucked) return;
    await music.duck();
  }

  Future<void> _unduckMusic() async {
    if (!_musicDuckingEnabled) return;
    final music = _music;
    if (music == null) return;
    await music.unduck();
  }

  // --- Cache Management ---

  Future<int> getCacheSizeBytes() => _voice.getCacheSizeBytes();
  Future<int> getCachedWorkoutCount() => _voice.getCachedWorkoutCount();
  Future<void> clearCache() => _voice.clearCache();
  Future<void> deleteWorkoutCache(String fingerprint) => _voice.deleteWorkoutCache(fingerprint);

  Future<List<CachedWorkoutInfo>> getCachedWorkouts() => _voice.getCachedWorkouts();

  Future<void> previewWorkoutClip(String fingerprint) async {
    if (await _voice.cacheExists(fingerprint)) {
      await _voice.playClip(fingerprint, 'workout_started');
    }
  }

  Future<void> rebuildCache(
    WorkoutFingerprint fingerprint,
    List<String> exerciseNames, {
    String? workoutName,
  }) async {
    await _voice.deleteWorkoutCache(fingerprint.compute());
    await generateWorkoutVoice(
      fingerprint: fingerprint,
      exerciseNames: exerciseNames,
      workoutName: workoutName,
    );
    if (fingerprint.compute() == _currentFingerprint) {
      await setExerciseList(exerciseNames);
    }
  }

  // --- Lifecycle ---

  Future<void> stop() async {
    _voiceQueue.clear();
    _voiceQueue.reset();
    await _voice.stop();
    await _voice.stopTts();
    await _sfx.stop();
    await _unduckMusic();
  }

  Future<void> dispose() async {
    _voiceQueue.clear();
    await _voice.dispose();
    await _sfx.dispose();
  }
}
