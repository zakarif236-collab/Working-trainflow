import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/services/gemini_voice_service.dart';
import 'package:my_app/services/sfx_service.dart';

class _FakeVoiceService extends GeminiVoiceService {
  bool cacheExistsResult = true;
  bool preloadedClipResult = false;
  bool clipResult = false;
  String? fallbackText;
  Completer<void>? fallbackCompleter;

  @override
  Future<bool> cacheExists(String fingerprint) async => cacheExistsResult;

  @override
  Future<void> preloadClips(String fingerprint, List<String> clipNames) async {}

  @override
  Future<bool> playPreloadedClip(String clipName) async => preloadedClipResult;

  @override
  Future<bool> playClip(String fingerprint, String clipName) async => clipResult;

  @override
  Future<void> speakFallback(String text) async {
    fallbackText = text;
    fallbackCompleter?.complete();
  }
}

void main() {
  const fingerprint = WorkoutFingerprint(
    workoutId: 'test',
    exerciseNames: ['Push Ups'],
    exerciseDurations: [30],
    restDurations: [30],
    recoveryDurations: [30],
  );

  Future<void> waitForFallback(_FakeVoiceService voice) async {
    final completer = Completer<void>();
    voice.fallbackCompleter = completer;
    if (voice.fallbackText != null) {
      completer.complete();
    }
    await completer.future.timeout(const Duration(seconds: 2));
  }

  test('announceCompletion speaks fallback TTS when preloaded clip is missing', () async {
    final voice = _FakeVoiceService()..preloadedClipResult = false;
    final engine = AudioEngine(voice: voice, sfx: SfxService());

    await engine.preloadWorkout(fingerprint);

    await engine.announceCompletion();
    await waitForFallback(voice);

    expect(voice.fallbackText, 'Workout complete!');
  });
}
