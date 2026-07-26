# Premium AI Voice Coach Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the robotic TTS voice experience with a premium AI voice coach powered by Gemini API, with fingerprint-based caching, premium countdown beeps, transition sounds, and music ducking.

**Architecture:** Three-service split: AudioEngine (orchestrator) → GeminiVoiceService (Gemini API TTS + cache) + SfxService (beeps/whoosh/victory). AudioEngine replaces CueService in both workout pages. WorkoutFingerprint model computes deterministic cache keys from workout content.

**Tech Stack:** Flutter/Dart, Gemini API (HTTP), just_audio, path_provider, shared_preferences, crypto (SHA-256)

## Global Constraints

- DO NOT modify workout logic, timer calculations, phase transitions, controllers
- DO NOT modify community system, workout builder, navigation, Firebase
- Only improve the audio presentation layer
- All audio settings saved to SharedPreferences
- Cache stored in app documents directory under `voice_cache/`

---

## File Structure

### New Files

| File | Responsibility |
|------|---------------|
| `lib/models/workout_fingerprint.dart` | Fingerprint computation from workout data |
| `lib/services/sfx_service.dart` | Countdown beeps, transition whoosh, victory fanfare |
| `lib/services/gemini_voice_service.dart` | Gemini API TTS + fingerprint-based local cache |
| `lib/services/audio_engine.dart` | Orchestrator: queue, ducking, preloading, settings |
| `lib/pages/audio_settings_page.dart` | Settings UI + cache management |

### Modified Files

| File | Changes |
|------|---------|
| `lib/services/settings_service.dart` | Add countdownBeepsEnabled, transitionSoundEnabled, musicDuckingEnabled to AppSettings |
| `lib/services/music_service.dart` | Expose setVolume() for ducking, add duckVolume/unduckVolume convenience methods |
| `lib/pages/workout_timer_page.dart` | Replace CueService with AudioEngine |
| `lib/pages/workout_builder_player_page.dart` | Replace CueService with AudioEngine |
| `pubspec.yaml` | Add crypto package dependency |

### Deleted Files

| File | Reason |
|------|--------|
| `lib/services/cue_service.dart` | Replaced by AudioEngine + GeminiVoiceService + SfxService |

---

## Task 1: WorkoutFingerprint Model

**Files:**
- Create: `lib/models/workout_fingerprint.dart`

**Interfaces:**
- Produces: `WorkoutFingerprint` class with `compute()` → `String` (8-char hex)

- [ ] **Step 1: Create WorkoutFingerprint class**

```dart
// lib/models/workout_fingerprint.dart
import 'dart:convert';
import 'package:crypto/crypto.dart';

class WorkoutFingerprint {
  const WorkoutFingerprint({
    required this.workoutId,
    required this.exerciseNames,
    required this.exerciseDurations,
    required this.restDurations,
    required this.recoveryDurations,
    this.voiceSelection = 'default_male',
    this.language = 'en',
    this.voiceModelVersion = '1.0',
  });

  final String workoutId;
  final List<String> exerciseNames;
  final List<int> exerciseDurations;
  final List<int> restDurations;
  final List<int> recoveryDurations;
  final String voiceSelection;
  final String language;
  final String voiceModelVersion;

  String compute() {
    final buffer = StringBuffer()
      ..write(workoutId)
      ..write('|')
      ..write(exerciseNames.join(','))
      ..write('|')
      ..write(exerciseDurations.join(','))
      ..write('|')
      ..write(restDurations.join(','))
      ..write('|')
      ..write(recoveryDurations.join(','))
      ..write('|')
      ..write(voiceSelection)
      ..write('|')
      ..write(language)
      ..write('|')
      ..write(voiceModelVersion);

    final bytes = utf8.encode(buffer.toString());
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 8).toUpperCase();
  }
}
```

- [ ] **Step 2: Add crypto dependency to pubspec.yaml**

Run: verify `crypto` is in pubspec.yaml dependencies. If not, add:
```yaml
  crypto: ^3.0.3
```

Then run: `flutter pub get`

- [ ] **Step 3: Verify fingerprint is deterministic**

Create a simple test in `test/models/workout_fingerprint_test.dart`:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_fingerprint.dart';

void main() {
  test('same inputs produce same fingerprint', () {
    final a = WorkoutFingerprint(
      workoutId: '123',
      exerciseNames: ['Burpees', 'Mountain Climbers'],
      exerciseDurations: [40, 45],
      restDurations: [20, 20],
      recoveryDurations: [0, 0],
    );
    final b = WorkoutFingerprint(
      workoutId: '123',
      exerciseNames: ['Burpees', 'Mountain Climbers'],
      exerciseDurations: [40, 45],
      restDurations: [20, 20],
      recoveryDurations: [0, 0],
    );
    expect(a.compute(), equals(b.compute()));
  });

  test('different inputs produce different fingerprint', () {
    final a = WorkoutFingerprint(
      workoutId: '123',
      exerciseNames: ['Burpees'],
      exerciseDurations: [40],
      restDurations: [20],
      recoveryDurations: [0],
    );
    final b = WorkoutFingerprint(
      workoutId: '123',
      exerciseNames: ['Push-ups'],
      exerciseDurations: [40],
      restDurations: [20],
      recoveryDurations: [0],
    );
    expect(a.compute(), isNot(equals(b.compute())));
  });

  test('fingerprint is 8-char hex', () {
    final fp = WorkoutFingerprint(
      workoutId: '123',
      exerciseNames: ['Burpees'],
      exerciseDurations: [40],
      restDurations: [20],
      recoveryDurations: [0],
    );
    final result = fp.compute();
    expect(result.length, equals(8));
    expect(RegExp(r'^[0-9A-F]{8}$').hasMatch(result), isTrue);
  });
}
```

Run: `flutter test test/models/workout_fingerprint_test.dart`
Expected: 3 tests pass

- [ ] **Step 4: Commit**

```bash
git add lib/models/workout_fingerprint.dart test/models/workout_fingerprint_test.dart pubspec.yaml pubspec.lock
git commit -m "feat: add WorkoutFingerprint model with SHA-256 cache key computation"
```

---

## Task 2: SfxService

**Files:**
- Create: `lib/services/sfx_service.dart`

**Interfaces:**
- Produces: `SfxService` class with `playCountdownTick(int)`, `playCountdownFinalBeep()`, `playTransitionWhoosh()`, `playVictorySound()`, `stop()`, `dispose()`

- [ ] **Step 1: Create SfxService with programmatically generated sounds**

```dart
// lib/services/sfx_service.dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class SfxService {
  AudioPlayer? _player;
  bool _initialized = false;
  String? _cacheDir;

  bool get isReady => _initialized && _player != null;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      _player = AudioPlayer();
      final dir = await getApplicationDocumentsDirectory();
      final sfxDir = Directory('${dir.path}/sfx_cache');
      if (!await sfxDir.exists()) {
        await sfxDir.create(recursive: true);
      }
      _cacheDir = sfxDir.path;
      _initialized = true;
    } catch (_) {
      _player = null;
      _initialized = false;
    }
  }

  Future<void> playCountdownTick(int secondsRemaining) async {
    if (!isReady || secondsRemaining <= 0 || secondsRemaining > 3) return;

    final frequencies = {3: 660.0, 2: 880.0, 1: 1100.0};
    final durations = {3: 150, 2: 180, 1: 250};
    final volumes = {3: 0.7, 2: 0.85, 1: 1.0};

    await _playGeneratedBeep(
      frequencyHz: frequencies[secondsRemaining]!,
      durationMs: durations[secondsRemaining]!,
      volume: volumes[secondsRemaining]!,
    );
  }

  Future<void> playCountdownFinalBeep() async {
    await _playGeneratedBeep(
      frequencyHz: 1320,
      durationMs: 300,
      volume: 1.0,
    );
  }

  Future<void> playTransitionWhoosh() async {
    await _playGeneratedWhoosh();
  }

  Future<void> playVictorySound() async {
    await _playGeneratedVictory();
  }

  Future<void> _playGeneratedBeep({
    required double frequencyHz,
    required int durationMs,
    required double volume,
  }) async {
    final player = _player;
    if (player == null) return;

    final sampleRate = 22050;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final data = _generateSineWaveWav(
      frequencyHz: frequencyHz,
      sampleRate: sampleRate,
      numSamples: numSamples,
      volume: volume,
    );

    final file = File('$_cacheDir/beep_${frequencyHz.round()}_$durationMs.wav');
    await file.writeAsBytes(data, flush: true);

    try {
      await player.setFilePath(file.path);
      await player.play();
    } catch (_) {}
  }

  Future<void> _playGeneratedWhoosh() async {
    final player = _player;
    if (player == null) return;

    final sampleRate = 22050;
    final durationMs = 300;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final data = _generateWhooshWav(
      sampleRate: sampleRate,
      numSamples: numSamples,
      volume: 0.85,
    );

    final file = File('$_cacheDir/whoosh_transition.wav');
    await file.writeAsBytes(data, flush: true);

    try {
      await player.setFilePath(file.path);
      await player.play();
    } catch (_) {}
  }

  Future<void> _playGeneratedVictory() async {
    final player = _player;
    if (player == null) return;

    final sampleRate = 22050;
    final durationMs = 800;
    final numSamples = (sampleRate * durationMs / 1000).round();
    final data = _generateVictoryWav(
      sampleRate: sampleRate,
      numSamples: numSamples,
      volume: 1.0,
    );

    final file = File('$_cacheDir/victory_fanfare.wav');
    await file.writeAsBytes(data, flush: true);

    try {
      await player.setFilePath(file.path);
      await player.play();
    } catch (_) {}
  }

  Uint8List _generateSineWaveWav({
    required double frequencyHz,
    required int sampleRate,
    required int numSamples,
    required double volume,
  }) {
    final amplitude = (volume * 32767).round().clamp(-32768, 32767);
    final byteRate = sampleRate * 1 * 2;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset, 0x52); offset++;
    buffer.setUint8(offset, 0x49); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
    buffer.setUint8(offset, 0x57); offset++;
    buffer.setUint8(offset, 0x41); offset++;
    buffer.setUint8(offset, 0x56); offset++;
    buffer.setUint8(offset, 0x45); offset++;

    // fmt chunk
    buffer.setUint8(offset, 0x66); offset++;
    buffer.setUint8(offset, 0x6D); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x20); offset++;
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little); offset += 4;
    buffer.setUint16(offset, 2, Endian.little); offset += 2;
    buffer.setUint16(offset, 16, Endian.little); offset += 2;

    // data chunk
    buffer.setUint8(offset, 0x64); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    final twoPiFOverSr = 2.0 * math.pi * frequencyHz / sampleRate;
    for (var i = 0; i < numSamples; i++) {
      final fadeOut = 1.0 - (i / numSamples);
      final sample = (amplitude * math.sin(twoPiFOverSr * i) * fadeOut).round();
      buffer.setInt16(offset, sample.clamp(-32768, 32767), Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  Uint8List _generateWhooshWav({
    required int sampleRate,
    required int numSamples,
    required double volume,
  }) {
    final amplitude = (volume * 32767).round().clamp(-32768, 32767);
    final byteRate = sampleRate * 1 * 2;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset, 0x52); offset++;
    buffer.setUint8(offset, 0x49); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
    buffer.setUint8(offset, 0x57); offset++;
    buffer.setUint8(offset, 0x41); offset++;
    buffer.setUint8(offset, 0x56); offset++;
    buffer.setUint8(offset, 0x45); offset++;

    // fmt chunk
    buffer.setUint8(offset, 0x66); offset++;
    buffer.setUint8(offset, 0x6D); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x20); offset++;
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little); offset += 4;
    buffer.setUint16(offset, 2, Endian.little); offset += 2;
    buffer.setUint16(offset, 16, Endian.little); offset += 2;

    // data chunk
    buffer.setUint8(offset, 0x64); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    // Whoosh: rising frequency sweep with noise
    final rng = math.Random(42);
    for (var i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      final freq = 200 + t * 2000; // Sweep from 200Hz to 2200Hz
      final envelope = t < 0.1 ? t / 0.1 : (1.0 - t) / 0.9; // Rise then fall
      final sine = math.sin(2.0 * math.pi * freq * t / sampleRate * i);
      final noise = (rng.nextDouble() * 2 - 1) * 0.3;
      final sample = ((sine * 0.7 + noise) * amplitude * envelope).round();
      buffer.setInt16(offset, sample.clamp(-32768, 32767), Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  Uint8List _generateVictoryWav({
    required int sampleRate,
    required int numSamples,
    required double volume,
  }) {
    final amplitude = (volume * 32767).round().clamp(-32768, 32767);
    final byteRate = sampleRate * 1 * 2;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset, 0x52); offset++;
    buffer.setUint8(offset, 0x49); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint8(offset, 0x46); offset++;
    buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
    buffer.setUint8(offset, 0x57); offset++;
    buffer.setUint8(offset, 0x41); offset++;
    buffer.setUint8(offset, 0x56); offset++;
    buffer.setUint8(offset, 0x45); offset++;

    // fmt chunk
    buffer.setUint8(offset, 0x66); offset++;
    buffer.setUint8(offset, 0x6D); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x20); offset++;
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint16(offset, 1, Endian.little); offset += 2;
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little); offset += 4;
    buffer.setUint16(offset, 2, Endian.little); offset += 2;
    buffer.setUint16(offset, 16, Endian.little); offset += 2;

    // data chunk
    buffer.setUint8(offset, 0x64); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint8(offset, 0x74); offset++;
    buffer.setUint8(offset, 0x61); offset++;
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    // Victory: major chord arpeggio (C-E-G-C) with swell
    final frequencies = [261.63, 329.63, 392.00, 523.25];
    for (var i = 0; i < numSamples; i++) {
      final t = i / numSamples;
      final swell = t < 0.1 ? t / 0.1 : (1.0 - (t - 0.1) / 0.9);
      var sample = 0.0;
      for (final freq in frequencies) {
        sample += math.sin(2.0 * math.pi * freq * i / sampleRate);
      }
      sample = (sample / frequencies.length) * amplitude * swell * 0.8;
      buffer.setInt16(offset, sample.round().clamp(-32768, 32767), Endian.little);
      offset += 2;
    }

    return buffer.buffer.asUint8List();
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  Future<void> dispose() async {
    await _player?.dispose();
    _player = null;
    _initialized = false;
  }
}
```

- [ ] **Step 2: Verify SfxService compiles**

Run: `flutter analyze lib/services/sfx_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/sfx_service.dart
git commit -m "feat: add SfxService with programmatic countdown beeps, whoosh, and victory sounds"
```

---

## Task 3: GeminiVoiceService

**Files:**
- Create: `lib/services/gemini_voice_service.dart`

**Interfaces:**
- Consumes: `GeminiConfig.apiKey`, `WorkoutFingerprint`
- Produces: `GeminiVoiceService` class with `generateAll(...)`, `getClip(String)`, `clearCache()`, `getCacheSizeBytes()`

- [ ] **Step 1: Create GeminiVoiceService with fingerprint-based cache**

```dart
// lib/services/gemini_voice_service.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:my_app/config/gemini_config.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:path_provider/path_provider.dart';

class GeminiVoiceService {
  AudioPlayer? _player;
  bool _initialized = false;
  String? _cacheRoot;
  final Map<String, AudioPlayer> _clipPlayers = {};

  bool get isReady => _initialized;

  // Standard coaching prompts
  static const Map<String, String> standardPrompts = {
    'workout_started': 'Workout started. Let\'s go!',
    'warmup': 'Warm up. Get ready.',
    'begin': 'Begin!',
    'work': 'Work!',
    'rest': 'Rest.',
    'recover': 'Recover.',
    'halfway_there': 'Halfway there!',
    'last_round': 'Last round!',
    'workout_complete': 'Workout complete!',
    'great_job': 'Great job!',
    'keep_going': 'Keep going!',
    'excellent_work': 'Excellent work.',
  };

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory('${dir.path}/voice_cache');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _cacheRoot = cacheDir.path;
      _player = AudioPlayer();
      _initialized = true;
    } catch (_) {
      _player = null;
      _initialized = false;
    }
  }

  String _workoutDir(String fingerprint) => '$_cacheRoot/$fingerprint';

  String _clipPath(String fingerprint, String clipName) =>
      '${_workoutDir(fingerprint)}/$clipName.mp3';

  String _manifestPath(String fingerprint) =>
      '${_workoutDir(fingerprint)}/manifest.json';

  Future<bool> cacheExists(String fingerprint) async {
    final manifest = File(_manifestPath(fingerprint));
    return manifest.exists();
  }

  Future<Set<String>> _loadCachedClipNames(String fingerprint) async {
    final manifestFile = File(_manifestPath(fingerprint));
    if (!await manifestFile.exists()) return {};
    try {
      final raw = await manifestFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map || !decoded.containsKey('clips')) return {};
      return Set<String>.from(decoded['clips']);
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveManifest(String fingerprint, Set<String> clipNames) async {
    final manifest = {
      'fingerprint': fingerprint,
      'generatedAt': DateTime.now().toIso8601String(),
      'voiceModelVersion': '1.0',
      'clips': clipNames.toList(),
    };
    await File(_manifestPath(fingerprint)).writeAsString(jsonEncode(manifest));
  }

  Future<void> generateAll({
    required String fingerprint,
    required List<String> exerciseNames,
    bool Function(double progress)? onProgress,
  }) async {
    if (!GeminiConfig.isConfigured) return;
    await initialize();

    final dir = Directory(_workoutDir(fingerprint));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final existingClips = await _loadCachedClipNames(fingerprint);
    final allClipNames = <String>{};

    // Build list of all clips needed
    final clipsToGenerate = <String, String>{};

    for (final entry in standardPrompts.entries) {
      allClipNames.add(entry.key);
      if (!existingClips.contains(entry.key)) {
        clipsToGenerate[entry.key] = entry.value;
      }
    }

    for (final name in exerciseNames) {
      final key = _exerciseClipKey(name);
      allClipNames.add(key);
      if (!existingClips.contains(key)) {
        clipsToGenerate[key] = 'Next exercise: $name.';
      }
    }

    // Add rest/recover if not already covered
    for (final key in ['rest', 'recover', 'workout_complete']) {
      if (!allClipNames.contains(key)) {
        allClipNames.add(key);
        if (!existingClips.contains(key) && standardPrompts.containsKey(key)) {
          clipsToGenerate[key] = standardPrompts[key]!;
        }
      }
    }

    // Generate missing clips
    final total = clipsToGenerate.length;
    var generated = 0;

    for (final entry in clipsToGenerate.entries) {
      final success = await _generateClip(
        fingerprint: fingerprint,
        clipName: entry.key,
        text: entry.value,
      );
      if (success) {
        existingClips.add(entry.key);
      }
      generated++;
      onProgress?.call(generated / total);
    }

    await _saveManifest(fingerprint, existingClips);
  }

  Future<bool> _generateClip({
    required String fingerprint,
    required String clipName,
    required String text,
  }) async {
    try {
      final audioData = await _callGeminiTts(text);
      if (audioData == null) return false;

      final file = File(_clipPath(fingerprint, clipName));
      await file.writeAsBytes(audioData, flush: true);
      return true;
    } catch (_) {
      // Retry once
      try {
        final audioData = await _callGeminiTts(text);
        if (audioData == null) return false;
        final file = File(_clipPath(fingerprint, clipName));
        await file.writeAsBytes(audioData, flush: true);
        return true;
      } catch (_) {
        return false;
      }
    }
  }

  Future<Uint8List?> _callGeminiTts(String text) async {
    if (!GeminiConfig.isConfigured) return null;

    final prompt = 'Generate audio of a deep, confident male fitness coach saying: "$text". '
        'The voice should be energetic, motivational, and professional. '
        'Natural pacing, clear pronunciation. No background noise.';

    try {
      final response = await http.post(
        Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=${GeminiConfig.apiKey}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['AUDIO', 'TEXT'],
          },
        }),
      );

      if (response.statusCode != 200) return null;

      final body = jsonDecode(response.body);
      final candidates = body['candidates'];
      if (candidates == null || candidates.isEmpty) return null;

      final content = candidates[0]['content'];
      if (content == null) return null;

      final parts = content['parts'];
      if (parts == null || parts.isEmpty) return null;

      for (final part in parts) {
        if (part.containsKey('inlineData')) {
          final data = part['inlineData']['data'];
          if (data != null) {
            return base64Decode(data);
          }
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  String _exerciseClipKey(String name) =>
      'exercise_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

  Future<void> playClip(String fingerprint, String clipName) async {
    final path = _clipPath(fingerprint, clipName);
    final file = File(path);
    if (!await file.exists()) return;

    final player = _player;
    if (player == null) return;

    try {
      await player.setFilePath(path);
      await player.play();
      await player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (_) {}
  }

  Future<void> preloadClips(String fingerprint, List<String> clipNames) async {
    // Dispose previous preloaded clips
    for (final player in _clipPlayers.values) {
      await player.dispose();
    }
    _clipPlayers.clear();

    for (final name in clipNames) {
      final path = _clipPath(fingerprint, name);
      final file = File(path);
      if (!await file.exists()) continue;

      try {
        final player = AudioPlayer();
        await player.setFilePath(path);
        _clipPlayers[name] = player;
      } catch (_) {}
    }
  }

  Future<void> playPreloadedClip(String clipName) async {
    final player = _clipPlayers[clipName];
    if (player == null) return;

    try {
      await player.seek(Duration.zero);
      await player.play();
    } catch (_) {}
  }

  Future<void> disposePreloadedClips() async {
    for (final player in _clipPlayers.values) {
      await player.dispose();
    }
    _clipPlayers.clear();
  }

  Future<int> getCacheSizeBytes() async {
    if (_cacheRoot == null) return 0;
    final dir = Directory(_cacheRoot!);
    if (!await dir.exists()) return 0;

    int totalSize = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        totalSize += await entity.length();
      }
    }
    return totalSize;
  }

  Future<int> getCachedWorkoutCount() async {
    if (_cacheRoot == null) return 0;
    final dir = Directory(_cacheRoot!);
    if (!await dir.exists()) return 0;

    int count = 0;
    await for (final entity in dir.list()) {
      if (entity is Directory) {
        final manifest = File('${entity.path}/manifest.json');
        if (await manifest.exists()) count++;
      }
    }
    return count;
  }

  Future<void> clearCache() async {
    if (_cacheRoot == null) return;
    final dir = Directory(_cacheRoot!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await initialize(); // Recreate root dir
  }

  Future<void> deleteWorkoutCache(String fingerprint) async {
    final dir = Directory(_workoutDir(fingerprint));
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
  }

  Future<void> stop() async {
    await _player?.stop();
  }

  Future<void> dispose() async {
    await _player?.dispose();
    for (final player in _clipPlayers.values) {
      await player.dispose();
    }
    _clipPlayers.clear();
    _player = null;
    _initialized = false;
  }
}
```

- [ ] **Step 2: Verify GeminiVoiceService compiles**

Run: `flutter analyze lib/services/gemini_voice_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/gemini_voice_service.dart
git commit -m "feat: add GeminiVoiceService with Gemini API TTS and fingerprint-based cache"
```

---

## Task 4: AudioEngine

**Files:**
- Create: `lib/services/audio_engine.dart`

**Interfaces:**
- Consumes: `GeminiVoiceService`, `SfxService`, `MusicService`
- Produces: `AudioEngine` class with full public API (announceExercise, playCountdownTick, etc.)

- [ ] **Step 1: Create AudioEngine orchestrator**

```dart
// lib/services/audio_engine.dart
import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
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
  double _voiceVolume = 0.8;
  bool _countdownBeepsEnabled = true;
  bool _transitionSoundEnabled = true;

  bool get isPreloaded => _isPreloaded;
  String? get currentFingerprint => _currentFingerprint;

  Future<void> initialize() async {
    await _voice.initialize();
    await _sfx.initialize();
  }

  void updateSettings({
    double? voiceVolume,
    bool? countdownBeepsEnabled,
    bool? transitionSoundEnabled,
    bool? musicDuckingEnabled,
  }) {
    if (voiceVolume != null) _voiceVolume = voiceVolume.clamp(0.0, 1.0);
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
    void Function(double progress)? onProgress,
  }) async {
    final fp = fingerprint.compute();
    _currentFingerprint = fp;

    await _voice.generateAll(
      fingerprint: fp,
      exerciseNames: exerciseNames,
      onProgress: onProgress,
    );

    await _voice.preloadClips(fp, [
      ...GeminiVoiceService.standardPrompts.keys,
      ...exerciseNames.map((n) => 'exercise_${n.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}'),
    ]);
    _isPreloaded = true;
  }

  // --- Voice Announcements ---

  Future<void> _speakClip(String clipName) async {
    final fp = _currentFingerprint;
    if (fp == null) return;

    await _voiceQueue.enqueue(() async {
      await _duckMusic();
      if (_isPreloaded) {
        await _voice.playPreloadedClip(clipName);
      } else {
        await _voice.playClip(fp, clipName);
      }
      await Future.delayed(const Duration(milliseconds: 500));
      await _unduckMusic();
    });
  }

  Future<void> announceWorkoutStarted() => _speakClip('workout_started');
  Future<void> announceWarmup() => _speakClip('warmup');
  Future<void> announceBegin() => _speakClip('begin');
  Future<void> announceWork() => _speakClip('work');
  Future<void> announceRest() => _speakClip('rest');
  Future<void> announceRecover() => _speakClip('recover');
  Future<void> announceHalfwayThere() => _speakClip('halfway_there');
  Future<void> announceLastRound() => _speakClip('last_round');
  Future<void> announceCompletion() => _speakClip('workout_complete');
  Future<void> announceGreatJob() => _speakClip('great_job');
  Future<void> announceKeepGoing() => _speakClip('keep_going');
  Future<void> announceExcellentWork() => _speakClip('excellent_work');

  Future<void> announceExercise(String name, {bool shouldSpeak = true}) async {
    if (!shouldSpeak) return;
    final clipKey = 'exercise_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    await _speakClip(clipKey);
  }

  Future<void> announcePhase(String label, {bool shouldSpeak = true}) async {
    if (!shouldSpeak) return;
    await announceExercise(label, shouldSpeak: shouldSpeak);
  }

  Future<void> speakCount(int seconds, {bool shouldSpeak = true}) async {
    if (!shouldSpeak || seconds < 1) return;
    // Count numbers use TTS fallback (no cached clip for dynamic numbers)
    // For now, skip speaking counts - beeps provide the countdown feedback
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

  Future<void> rebuildCache(WorkoutFingerprint fingerprint, List<String> exerciseNames) async {
    await _voice.deleteWorkoutCache(fingerprint.compute());
    await generateWorkoutVoice(fingerprint: fingerprint, exerciseNames: exerciseNames);
  }

  // --- Lifecycle ---

  Future<void> stop() async {
    _voiceQueue.clear();
    _voiceQueue.reset();
    await _voice.stop();
    await _sfx.stop();
    await _unduckMusic();
  }

  Future<void> dispose() async {
    _voiceQueue.clear();
    await _voice.dispose();
    await _sfx.dispose();
  }
}
```

- [ ] **Step 2: Verify AudioEngine compiles**

Run: `flutter analyze lib/services/audio_engine.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/audio_engine.dart
git commit -m "feat: add AudioEngine orchestrator with voice queue, ducking, and preloading"
```

---

## Task 5: Update MusicService for Ducking

**Files:**
- Modify: `lib/services/music_service.dart`

**Interfaces:**
- Consumes: nothing new
- Produces: `setVolume(double)` method for AudioEngine ducking

- [ ] **Step 1: Add public setVolume method to MusicService**

In `lib/services/music_service.dart`, add after the `unduck()` method:

```dart
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }
```

- [ ] **Step 2: Verify no regressions**

Run: `flutter analyze lib/services/music_service.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/services/music_service.dart
git commit -m "feat: expose setVolume on MusicService for AudioEngine ducking"
```

---

## Task 6: Update SettingsService

**Files:**
- Modify: `lib/services/settings_service.dart`

**Interfaces:**
- Consumes: nothing new
- Produces: New fields in `AppSettings`, new SharedPreferences keys

- [ ] **Step 1: Add new fields to AppSettings**

In `lib/services/settings_service.dart`, update the `AppSettings` class:

```dart
class AppSettings {
  const AppSettings({
    required this.config,
    required this.voiceCueEnabled,
    required this.hapticCueEnabled,
    required this.muteVoiceWhileMusicPlays,
    required this.voiceCueVolume,
    required this.voiceCueRate,
    this.countdownBeepsEnabled = true,
    this.transitionSoundEnabled = true,
    this.musicDuckingEnabled = true,
  });

  final WorkoutConfig config;
  final bool voiceCueEnabled;
  final bool hapticCueEnabled;
  final bool muteVoiceWhileMusicPlays;
  final double voiceCueVolume;
  final double voiceCueRate;
  final bool countdownBeepsEnabled;
  final bool transitionSoundEnabled;
  final bool musicDuckingEnabled;

  static AppSettings defaults() {
    return AppSettings(
      config: WorkoutConfig.defaults,
      voiceCueEnabled: true,
      hapticCueEnabled: true,
      muteVoiceWhileMusicPlays: true,
      voiceCueVolume: 1.0,
      voiceCueRate: 0.52,
      countdownBeepsEnabled: true,
      transitionSoundEnabled: true,
      musicDuckingEnabled: true,
    );
  }
}
```

- [ ] **Step 2: Update load() method**

In the `load()` method of `SettingsService`, add after `voiceCueRate`:

```dart
      countdownBeepsEnabled: prefs.getBool(_kCountdownBeepsEnabled) ?? defaults.countdownBeepsEnabled,
      transitionSoundEnabled: prefs.getBool(_kTransitionSoundEnabled) ?? defaults.transitionSoundEnabled,
      musicDuckingEnabled: prefs.getBool(_kMusicDuckingEnabled) ?? defaults.musicDuckingEnabled,
```

- [ ] **Step 3: Update save() method**

In the `save()` method of `SettingsService`, add after `voiceCueRate`:

```dart
    await prefs.setBool(_kCountdownBeepsEnabled, settings.countdownBeepsEnabled);
    await prefs.setBool(_kTransitionSoundEnabled, settings.transitionSoundEnabled);
    await prefs.setBool(_kMusicDuckingEnabled, settings.musicDuckingEnabled);
```

- [ ] **Step 4: Add SharedPreferences keys**

At the bottom of `lib/services/settings_service.dart`, add:

```dart
const _kCountdownBeepsEnabled = 'settings.countdownBeepsEnabled';
const _kTransitionSoundEnabled = 'settings.transitionSoundEnabled';
const _kMusicDuckingEnabled = 'settings.musicDuckingEnabled';
```

- [ ] **Step 5: Verify no regressions**

Run: `flutter analyze lib/services/settings_service.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add countdownBeepsEnabled, transitionSoundEnabled, musicDuckingEnabled to AppSettings"
```

---

## Task 7: Audio Settings Page

**Files:**
- Create: `lib/pages/audio_settings_page.dart`

**Interfaces:**
- Consumes: `AudioEngine`, `AppSettings`
- Produces: Full settings UI with cache management

- [ ] **Step 1: Create AudioSettingsPage**

```dart
// lib/pages/audio_settings_page.dart
import 'package:flutter/material.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/services/settings_service.dart';

class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({
    super.key,
    required this.audioEngine,
    required this.settings,
    required this.onSettingsChanged,
  });

  final AudioEngine audioEngine;
  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
  late bool _voiceEnabled;
  late double _voiceVolume;
  late double _speechRate;
  late bool _countdownBeeps;
  late bool _transitionSound;
  late bool _musicDucking;

  int _cacheSizeBytes = 0;
  int _cachedWorkouts = 0;

  @override
  void initState() {
    super.initState();
    _voiceEnabled = widget.settings.voiceCueEnabled;
    _voiceVolume = widget.settings.voiceCueVolume;
    _speechRate = widget.settings.voiceCueRate;
    _countdownBeeps = widget.settings.countdownBeepsEnabled;
    _transitionSound = widget.settings.transitionSoundEnabled;
    _musicDucking = widget.settings.musicDuckingEnabled;
    _loadCacheInfo();
  }

  Future<void> _loadCacheInfo() async {
    final size = await widget.audioEngine.getCacheSizeBytes();
    final count = await widget.audioEngine.getCachedWorkoutCount();
    if (mounted) {
      setState(() {
        _cacheSizeBytes = size;
        _cachedWorkouts = count;
      });
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Audio Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSection(
            'VOICE COACH',
            [
              _buildSwitch('Voice Guidance', _voiceEnabled, (v) {
                setState(() => _voiceEnabled = v);
                widget.onSettingsChanged();
              }),
              _buildSlider('Voice Volume', _voiceVolume, (v) {
                setState(() => _voiceVolume = v);
                widget.audioEngine.updateSettings(voiceVolume: v);
                widget.onSettingsChanged();
              }),
              _buildSlider('Speech Speed', _speechRate, (v) {
                setState(() => _speechRate = v);
                widget.onSettingsChanged();
              }, min: 0.2, max: 0.8),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'SOUND EFFECTS',
            [
              _buildSwitch('Countdown Beeps', _countdownBeeps, (v) {
                setState(() => _countdownBeeps = v);
                widget.audioEngine.updateSettings(countdownBeepsEnabled: v);
                widget.onSettingsChanged();
              }),
              _buildSwitch('Transition Sound', _transitionSound, (v) {
                setState(() => _transitionSound = v);
                widget.audioEngine.updateSettings(transitionSoundEnabled: v);
                widget.onSettingsChanged();
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'MUSIC',
            [
              _buildSwitch('Music Ducking', _musicDucking, (v) {
                setState(() => _musicDucking = v);
                widget.audioEngine.updateSettings(musicDuckingEnabled: v);
                widget.onSettingsChanged();
              }),
            ],
          ),
          const SizedBox(height: 24),
          _buildSection(
            'VOICE CACHE',
            [
              ListTile(
                title: const Text('Cache Size', style: TextStyle(color: Colors.white70)),
                trailing: Text(_formatBytes(_cacheSizeBytes), style: const TextStyle(color: Colors.white54)),
              ),
              ListTile(
                title: const Text('Cached Workouts', style: TextStyle(color: Colors.white70)),
                trailing: Text('$_cachedWorkouts', style: const TextStyle(color: Colors.white54)),
              ),
              ListTile(
                title: const Text('Clear All Cache', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  await widget.audioEngine.clearCache();
                  await _loadCacheInfo();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Cache cleared')),
                    );
                  }
                },
              ),
              ListTile(
                title: const Text('Rebuild Current Workout', style: TextStyle(color: Color(0xFFF59E0B))),
                onTap: () async {
                  // TODO: rebuild current workout cache
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(color: Colors.white70)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF22C55E),
    );
  }

  Widget _buildSlider(String label, double value, ValueChanged<double> onChanged, {
    double min = 0.0,
    double max = 1.0,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: Colors.white70)),
              Text('${(value * 100).round()}%', style: const TextStyle(color: Colors.white54)),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
            activeColor: const Color(0xFF22C55E),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify AudioSettingsPage compiles**

Run: `flutter analyze lib/pages/audio_settings_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/pages/audio_settings_page.dart
git commit -m "feat: add AudioSettingsPage with voice coach, sound effects, music, and cache management"
```

---

## Task 8: Wire AudioEngine into workout_timer_page.dart

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `AudioEngine` (replaces `CueService`)
- Produces: Updated workout timer using AudioEngine for all audio

- [ ] **Step 1: Update imports**

Replace:
```dart
import 'package:my_app/services/cue_service.dart';
```

With:
```dart
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/services/sfx_service.dart';
import 'package:my_app/services/gemini_voice_service.dart';
import 'package:my_app/models/workout_fingerprint.dart';
import 'package:my_app/pages/audio_settings_page.dart';
```

- [ ] **Step 2: Replace CueService with AudioEngine**

Find the state class declaration and replace:
```dart
late final CueService _cueService;
```

With:
```dart
late final AudioEngine _audioEngine;
```

- [ ] **Step 3: Update initState**

Find where `_cueService = CueService();` is called and replace with:
```dart
    _audioEngine = AudioEngine(
      voice: GeminiVoiceService(),
      sfx: SfxService(),
      music: _musicService,
    );
    _audioEngine.initialize();
```

- [ ] **Step 4: Update settings initialization**

Find where `_cueService.updateSettings(...)` is called and replace with:
```dart
    _audioEngine.updateSettings(
      voiceVolume: saved.voiceCueVolume,
      countdownBeepsEnabled: saved.countdownBeepsEnabled,
      transitionSoundEnabled: saved.transitionSoundEnabled,
      musicDuckingEnabled: saved.musicDuckingEnabled,
    );
```

- [ ] **Step 5: Replace all _cueService calls**

Find and replace all occurrences:
- `_cueService.announceExercise(...)` → `_audioEngine.announceExercise(...)`
- `_cueService.announceRest(...)` → `_audioEngine.announceRest(...)`
- `_cueService.announcePhase(...)` → `_audioEngine.announcePhase(...)`
- `_cueService.speakCount(...)` → `_audioEngine.speakCount(...)`
- `_cueService.announceCompletion()` → `_audioEngine.announceCompletion()`
- `_cueService.playCountdownTick(...)` → `_audioEngine.playCountdownTick(...)`
- `_cueService.playCountdownFinalBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.playPhaseCompletionBeep()` → `_audioEngine.playPhaseCompletionBeep()`
- `_cueService.playWorkoutCompletionBeep()` → `_audioEngine.playWorkoutCompletionBeep()`
- `_cueService.stop()` → `_audioEngine.stop()`

- [ ] **Step 6: Update dispose**

Find `_cueService.dispose();` and replace with `_audioEngine.dispose();`

- [ ] **Step 7: Add Audio Settings navigation**

Find where audio settings toggles are in the config panel. Add a button that navigates to AudioSettingsPage:
```dart
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AudioSettingsPage(
                      audioEngine: _audioEngine,
                      settings: _settingsService.load() as AppSettings, // or however settings are loaded
                      onSettingsChanged: () {
                        setState(() {});
                      },
                    ),
                  ),
                );
              },
```

- [ ] **Step 8: Verify no regressions**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No issues found (warnings about unused imports OK for now)

- [ ] **Step 9: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "feat: replace CueService with AudioEngine in workout_timer_page"
```

---

## Task 9: Wire AudioEngine into workout_builder_player_page.dart

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `AudioEngine` (replaces `CueService`)
- Produces: Updated builder player using AudioEngine for all audio

- [ ] **Step 1: Update imports**

Replace:
```dart
import 'package:my_app/services/cue_service.dart';
```

With:
```dart
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/services/sfx_service.dart';
import 'package:my_app/services/gemini_voice_service.dart';
```

- [ ] **Step 2: Replace CueService with AudioEngine**

Find and replace:
```dart
final CueService _cueService = CueService();
```

With:
```dart
final AudioEngine _audioEngine = AudioEngine(
  voice: GeminiVoiceService(),
  sfx: SfxService(),
);
```

- [ ] **Step 3: Update settings initialization**

Find where `_cueService.updateSettings(...)` is called and replace with:
```dart
    _audioEngine.updateSettings(
      voiceVolume: settings.voiceCueVolume,
      countdownBeepsEnabled: settings.countdownBeepsEnabled,
      transitionSoundEnabled: settings.transitionSoundEnabled,
      musicDuckingEnabled: settings.musicDuckingEnabled,
    );
```

- [ ] **Step 4: Replace all _cueService calls**

Find and replace all occurrences:
- `_cueService.announceExercise(...)` → `_audioEngine.announceExercise(...)`
- `_cueService.announceRest(...)` → `_audioEngine.announceRest(...)`
- `_cueService.announcePhase(...)` → `_audioEngine.announcePhase(...)`
- `_cueService.speakCount(...)` → `_audioEngine.speakCount(...)`
- `_cueService.announceCompletion()` → `_audioEngine.announceCompletion()`
- `_cueService.playCountdownTick(...)` → `_audioEngine.playCountdownTick(...)`
- `_cueService.playCountdownFinalBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.playCountdownBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.playPhaseCompletionBeep()` → `_audioEngine.playPhaseCompletionBeep()`
- `_cueService.playWorkoutCompletionBeep()` → `_audioEngine.playWorkoutCompletionBeep()`

- [ ] **Step 5: Update dispose**

Find `_cueService.dispose();` and replace with `_audioEngine.dispose();`

- [ ] **Step 6: Verify no regressions**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat: replace CueService with AudioEngine in workout_builder_player_page"
```

---

## Task 10: Delete CueService and Final Cleanup

**Files:**
- Delete: `lib/services/cue_service.dart`
- Modify: `lib/pages/workout_timer_page.dart` (remove unused imports)
- Modify: `lib/pages/workout_builder_player_page.dart` (remove unused imports)

- [ ] **Step 1: Delete CueService**

```bash
rm lib/services/cue_service.dart
```

- [ ] **Step 2: Remove any remaining CueService references**

Run: `grep -r "CueService" lib/`
Expected: No results

- [ ] **Step 3: Clean up unused imports**

Run: `flutter analyze`
Fix any unused import warnings.

- [ ] **Step 4: Final full analysis**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 5: Final commit**

```bash
git add -A
git commit -m "feat: delete CueService, final cleanup for premium voice coach"
```

---

## Task 11: End-to-End Verification

- [ ] **Step 1: Verify all files compile**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Check for any remaining CueService references**

Run: `grep -r "cue_service\|CueService" lib/`
Expected: No results

- [ ] **Step 3: Verify AudioEngine is used in both workout pages**

Run: `grep -r "AudioEngine\|_audioEngine" lib/pages/`
Expected: Both workout_timer_page.dart and workout_builder_player_page.dart reference AudioEngine

- [ ] **Step 4: Verify settings keys are consistent**

Run: `grep -r "countdownBeepsEnabled\|transitionSoundEnabled\|musicDuckingEnabled" lib/`
Expected: Keys appear in settings_service.dart, audio_settings_page.dart, and audio_engine.dart

- [ ] **Step 5: Commit any final fixes**

```bash
git add -A
git commit -m "chore: final verification and cleanup for premium voice coach"
```
