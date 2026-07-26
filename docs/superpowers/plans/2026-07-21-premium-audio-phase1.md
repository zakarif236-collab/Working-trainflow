# Premium Audio Experience - Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the monolithic CueService with a three-service audio architecture (AudioEngine + VoiceService + SfxService) featuring premium male voice coaching, improved countdown beeps, and a dedicated audio settings page.

**Architecture:** AudioEngine orchestrates VoiceService (bundled Google Cloud TTS clips + flutter_tts fallback) and SfxService (programmatically generated countdown beeps). MusicService is reused unchanged. The old CueService is deleted.

**Tech Stack:** Flutter, just_audio, flutter_tts (local override), shared_preferences, Google Cloud TTS (one-time script)

## Global Constraints

- Flutter SDK ^3.12.2
- google_sign_in: ^6.2.2, firebase_auth: ^5.5.4
- flutter_tts: ^4.2.3 (local override at third_party/flutter_tts)
- just_audio: ^0.10.5
- Platform support: Voice cues disabled on web and Windows (existing behavior preserved)
- All audio assets go in `assets/audio/voice/` and `assets/audio/sfx/`
- Beeps remain programmatically generated (no asset files for beeps)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/services/voice_service.dart` | **Create** | Load bundled TTS clips, play them, fall back to flutter_tts for custom names |
| `lib/services/sfx_service.dart` | **Create** | Pre-generate countdown beeps as WAVs, play them on demand |
| `lib/services/audio_engine.dart` | **Create** | Orchestrator: coordinates voice + sfx, manages settings, handles ducking stub |
| `lib/pages/audio_settings_page.dart` | **Create** | Dedicated settings UI for audio preferences |
| `tools/generate_voice_clips.dart` | **Create** | One-time script to generate voice clips via Google Cloud TTS |
| `assets/audio/voice/*.mp3` | **Create** | 10 pre-generated voice clips |
| `lib/services/settings_service.dart` | **Modify** | Add new audio settings to AppSettings + SharedPreferences keys |
| `lib/pages/workout_timer_page.dart` | **Modify** | Replace CueService with AudioEngine |
| `lib/pages/workout_builder_player_page.dart` | **Modify** | Replace CueService with AudioEngine |
| `pubspec.yaml` | **Modify** | Add `assets/audio/` to flutter assets |
| `lib/services/cue_service.dart` | **Delete** | Replaced by AudioEngine + VoiceService + SfxService |

---

### Task 1: Generate voice clips with Google Cloud TTS

**Files:**
- Create: `tools/generate_voice_clips.dart`
- Create: `assets/audio/voice/` (10 MP3 files)

**Interfaces:**
- Produces: 10 MP3 files in `assets/audio/voice/` that VoiceService will load in Task 3

- [ ] **Step 1: Create the voice clips directory**

```bash
mkdir -p assets/audio/voice
```

- [ ] **Step 2: Create the generation script**

Create `tools/generate_voice_clips.dart`:

```dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// One-time script to generate premium male voice clips via Google Cloud TTS.
///
/// Usage:
///   dart run tools/generate_voice_clips.dart YOUR_GOOGLE_CLOUD_API_KEY
///
/// Requires a Google Cloud project with Text-to-Speech API enabled.
/// Get an API key from: https://console.cloud.google.com/apis/credentials

const _prompts = <String, String>{
  'workout_started': 'Workout started. Let\'s go!',
  'begin': 'Begin!',
  'rest': 'Rest.',
  'recover': 'Recover.',
  'halfway_there': 'Halfway there!',
  'last_round': 'Last round!',
  'workout_complete': 'Workout complete.',
  'great_job': 'Great job!',
  'keep_going': 'Keep going!',
  'excellent_work': 'Excellent work.',
};

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Usage: dart run tools/generate_voice_clips.dart <GOOGLE_CLOUD_API_KEY>');
    exit(1);
  }

  final apiKey = args.first;
  final outputDir = Directory('assets/audio/voice');
  if (!outputDir.existsSync()) {
    outputDir.createSync(recursive: true);
  }

  for (final entry in _prompts.entries) {
    final key = entry.key;
    final text = entry.value;
    final outputFile = File('${outputDir.path}/$key.mp3');

    print('Generating: $key.mp3 ...');
    await _generateClip(apiKey, text, outputFile);
    print('  -> ${outputFile.path} (${outputFile.lengthSync()} bytes)');
  }

  print('\nDone! ${_prompts.length} voice clips generated.');
}

Future<void> _generateClip(String apiKey, String text, File outputFile) async {
  final url = Uri.parse(
    'https://texttospeech.googleapis.com/v1/text:synthesize?key=$apiKey',
  );

  final body = jsonEncode({
    'input': {'text': text},
    'voice': {
      'languageCode': 'en-US',
      'name': 'en-US-Neural2-D',
      'ssmlGender': 'MALE',
    },
    'audioConfig': {
      'audioEncoding': 'MP3',
      'speakingRate': 0.9,
      'pitch': -2.0,
    },
  });

  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: body,
  );

  if (response.statusCode != 200) {
    throw Exception('TTS API error ${response.statusCode}: ${response.body}');
  }

  final data = jsonDecode(response.body);
  final audioContent = data['audioContent'] as String;
  final audioBytes = base64Decode(audioContent);
  await outputFile.writeAsBytes(audioBytes, flush: true);
}
```

- [ ] **Step 3: Run the script**

```bash
dart pub add http
dart run tools/generate_voice_clips.dart YOUR_API_KEY
```

Expected: 10 MP3 files created in `assets/audio/voice/`, each < 50KB.

- [ ] **Step 4: Remove http dependency (one-time use)**

```bash
dart pub remove http
```

- [ ] **Step 5: Commit**

```bash
git add assets/audio/voice/ tools/generate_voice_clips.dart
git commit -m "feat: add premium voice clips generated via Google Cloud TTS"
```

---

### Task 2: Add audio assets to pubspec.yaml

**Files:**
- Modify: `pubspec.yaml` (add assets section)

**Interfaces:**
- Produces: Asset bundle paths that VoiceService and SfxService will load from

- [ ] **Step 1: Read current pubspec.yaml**

Check the current `flutter.assets` section. It currently has:
```yaml
  assets:
    - assets/exercises/images/
    - assets/exercises/videos/
```

- [ ] **Step 2: Add audio asset paths**

In `pubspec.yaml`, add the audio directories to the existing `assets` section:

```yaml
  assets:
    - assets/exercises/images/
    - assets/exercises/videos/
    - assets/audio/voice/
```

- [ ] **Step 3: Verify assets are recognized**

```bash
flutter pub get
flutter analyze lib/main.dart
```

Expected: No errors about missing assets.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml
git commit -m "feat: register audio voice assets in pubspec.yaml"
```

---

### Task 3: Create VoiceService

**Files:**
- Create: `lib/services/voice_service.dart`

**Interfaces:**
- Consumes: Bundled MP3 files from `assets/audio/voice/`
- Consumes: `flutter_tts` (local override at `third_party/flutter_tts`)
- Produces: `VoiceService` class with `initialize()`, `speakPrompt()`, `speakCustom()`, `stop()`, `dispose()`, `updateSettings()`

- [ ] **Step 1: Create VoiceService**

Create `lib/services/voice_service.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

class VoiceService {
  VoiceService();

  static bool get _supportsVoice =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  FlutterTts? _tts;
  AudioPlayer? _player;
  bool _initialized = false;
  double _volume = 0.8;
  double _speechRate = 0.52;

  /// Maps prompt keys (e.g. 'begin') to bundled asset paths.
  final Map<String, String> _clipPaths = {};

  bool get supportsVoice => _supportsVoice;

  Future<void> initialize() async {
    if (!_supportsVoice || _initialized) return;
    _initialized = true;

    try {
      _player = AudioPlayer();
    } catch (_) {
      _player = null;
    }

    // Pre-load clip paths from asset bundle.
    const clipKeys = [
      'workout_started',
      'begin',
      'rest',
      'recover',
      'halfway_there',
      'last_round',
      'workout_complete',
      'great_job',
      'keep_going',
      'excellent_work',
    ];

    for (final key in clipKeys) {
      _clipPaths[key] = 'assets/audio/voice/$key.mp3';
    }
  }

  Future<void> _ensureTts() async {
    if (_tts != null) return;
    try {
      _tts = FlutterTts();
      await _tts!.setVolume(_volume);
      await _tts!.setPitch(0.85);
      await _tts!.setSpeechRate(_speechRate);
      await _tts!.awaitSpeakCompletion(true);
    } catch (_) {
      _tts = null;
    }
  }

  /// Speak a bundled voice clip by key (e.g. 'begin', 'rest').
  Future<void> speakPrompt(String key) async {
    if (!_supportsVoice) return;

    final assetPath = _clipPaths[key];
    if (assetPath == null) return;

    final player = _player;
    if (player == null) return;

    try {
      await player.setAsset(assetPath);
      await player.setVolume(_volume);
      await player.play();
      await player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
    } catch (_) {
      // Fallback to TTS if asset playback fails.
      await _speakFallback(key);
    }
  }

  /// Speak arbitrary text using flutter_tts (for custom exercise names).
  Future<void> speakCustom(String text) async {
    if (!_supportsVoice || text.trim().isEmpty) return;

    await _ensureTts();
    final tts = _tts;
    if (tts == null) return;

    try {
      await tts.speak(text.trim());
    } catch (_) {
      // Best effort
    }
  }

  Future<void> _speakFallback(String key) async {
    await _ensureTts();
    final tts = _tts;
    if (tts == null) return;

    // Convert key to readable text.
    final text = key.replaceAll('_', ' ');
    try {
      await tts.speak(text);
    } catch (_) {
      // Best effort
    }
  }

  Future<void> updateSettings({double? volume, double? speechRate}) async {
    if (volume != null) _volume = volume.clamp(0.0, 1.0);
    if (speechRate != null) _speechRate = speechRate.clamp(0.2, 0.8);

    final tts = _tts;
    if (tts != null) {
      try {
        await tts.setVolume(_volume);
        await tts.setSpeechRate(_speechRate);
      } catch (_) {
        // Best effort
      }
    }
  }

  Future<void> stop() async {
    final tts = _tts;
    if (tts != null) {
      try {
        await tts.stop();
      } catch (_) {
        // Best effort
      }
    }
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // Best effort
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    final player = _player;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // Best effort
      }
    }
    _tts = null;
    _player = null;
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/services/voice_service.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/voice_service.dart
git commit -m "feat: create VoiceService for bundled TTS clips and custom speech"
```

---

### Task 4: Create SfxService

**Files:**
- Create: `lib/services/sfx_service.dart`

**Interfaces:**
- Produces: `SfxService` class with `initialize()`, `playCountdownTick()`, `playCountdownFinalBeep()`, `stop()`, `dispose()`

- [ ] **Step 1: Create SfxService**

Create `lib/services/sfx_service.dart`:

```dart
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

class SfxService {
  SfxService();

  static bool get _supportsSfx =>
      !kIsWeb && defaultTargetPlatform != TargetPlatform.windows;

  AudioPlayer? _player;
  bool _initialized = false;
  final Map<String, String> _beepCache = {};

  Future<void> initialize() async {
    if (!_supportsSfx || _initialized) return;
    _initialized = true;

    try {
      _player = AudioPlayer();
    } catch (_) {
      _player = null;
    }

    // Pre-generate all countdown beeps.
    await _preGenerateBeeps();
  }

  Future<void> _preGenerateBeeps() async {
    final tempDir = await getTemporaryDirectory();
    final specs = [
      _BeepSpec(3, 660.0, 150, 0.7),
      _BeepSpec(2, 880.0, 180, 0.85),
      _BeepSpec(1, 1100.0, 250, 1.0),
    ];

    for (final spec in specs) {
      final path = '${tempDir.path}${Platform.pathSeparator}sfx_beep_${spec.seconds}s.wav';
      final file = File(path);
      if (!await file.exists()) {
        final data = _generateSineWaveWav(
          frequencyHz: spec.frequencyHz,
          sampleRate: 22050,
          durationMs: spec.durationMs,
          volume: spec.volume,
        );
        await file.writeAsBytes(data, flush: true);
      }
      _beepCache['${spec.seconds}s'] = path;
    }
  }

  /// Play a countdown tick for the given seconds remaining (3, 2, or 1).
  Future<void> playCountdownTick(int secondsRemaining) async {
    if (!_supportsSfx || secondsRemaining < 1 || secondsRemaining > 3) return;

    final path = _beepCache['${secondsRemaining}s'];
    if (path == null) return;

    final player = _player;
    if (player == null) return;

    try {
      await player.setFilePath(path);
      await player.play();
    } catch (_) {
      // Best effort
    }
  }

  /// Play the final countdown beep (1 second remaining).
  Future<void> playCountdownFinalBeep() async {
    await playCountdownTick(1);
  }

  Future<void> stop() async {
    final player = _player;
    if (player != null) {
      try {
        await player.stop();
      } catch (_) {
        // Best effort
      }
    }
  }

  Future<void> dispose() async {
    await stop();
    final player = _player;
    if (player != null) {
      try {
        await player.dispose();
      } catch (_) {
        // Best effort
      }
    }
    _player = null;
  }

  Uint8List _generateSineWaveWav({
    required double frequencyHz,
    required int sampleRate,
    required int durationMs,
    required double volume,
  }) {
    final numSamples = (sampleRate * durationMs / 1000).round();
    final amplitude = (volume * 32767).round().clamp(-32768, 32767);
    final byteRate = sampleRate * 1 * 2;
    final dataSize = numSamples * 2;
    final fileSize = 36 + dataSize;

    final buffer = ByteData(44 + dataSize);
    var offset = 0;

    // RIFF header
    buffer.setUint8(offset, 0x52); offset++; // R
    buffer.setUint8(offset, 0x49); offset++; // I
    buffer.setUint8(offset, 0x46); offset++; // F
    buffer.setUint8(offset, 0x46); offset++; // F
    buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
    buffer.setUint8(offset, 0x57); offset++; // W
    buffer.setUint8(offset, 0x41); offset++; // A
    buffer.setUint8(offset, 0x56); offset++; // V
    buffer.setUint8(offset, 0x45); offset++; // E

    // fmt chunk
    buffer.setUint8(offset, 0x66); offset++; // f
    buffer.setUint8(offset, 0x6D); offset++; // m
    buffer.setUint8(offset, 0x74); offset++; // t
    buffer.setUint8(offset, 0x20); offset++; // (space)
    buffer.setUint32(offset, 16, Endian.little); offset += 4;
    buffer.setUint16(offset, 1, Endian.little); offset += 2; // PCM
    buffer.setUint16(offset, 1, Endian.little); offset += 2; // mono
    buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
    buffer.setUint32(offset, byteRate, Endian.little); offset += 4;
    buffer.setUint16(offset, 2, Endian.little); offset += 2;
    buffer.setUint16(offset, 16, Endian.little); offset += 2;

    // data chunk
    buffer.setUint8(offset, 0x64); offset++; // d
    buffer.setUint8(offset, 0x61); offset++; // a
    buffer.setUint8(offset, 0x74); offset++; // t
    buffer.setUint8(offset, 0x61); offset++; // a
    buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

    // Generate sine wave with fade-out envelope
    final twoPiFOverSr = 2.0 * 3.141592653589793 * frequencyHz / sampleRate;
    for (var i = 0; i < numSamples; i++) {
      final fadeOut = 1.0 - i / numSamples;
      final sample = (amplitude * math.sin(twoPiFOverSr * i) * fadeOut).round();
      buffer.setInt16(offset, sample.clamp(-32768, 32767), Endian.little);
      offset += 2;
    }

    final bytes = Uint8List(44 + dataSize);
    final byteBuffer = buffer.buffer.asByteData();
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = byteBuffer.getUint8(i);
    }
    return bytes;
  }
}

class _BeepSpec {
  const _BeepSpec(this.seconds, this.frequencyHz, this.durationMs, this.volume);
  final int seconds;
  final double frequencyHz;
  final int durationMs;
  final double volume;
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/services/sfx_service.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/sfx_service.dart
git commit -m "feat: create SfxService for programmatically generated countdown beeps"
```

---

### Task 5: Add audio settings to SettingsService

**Files:**
- Modify: `lib/services/settings_service.dart` (AppSettings class + load/save + constants)

**Interfaces:**
- Consumes: Existing `AppSettings` class and `SettingsService`
- Produces: Updated `AppSettings` with new fields, updated `load()` and `save()` methods

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
    required this.maleVoiceEnabled,
    required this.countdownBeepsEnabled,
    required this.transitionSirenEnabled,
    required this.musicDuckingEnabled,
  });

  final WorkoutConfig config;
  final bool voiceCueEnabled;
  final bool hapticCueEnabled;
  final bool muteVoiceWhileMusicPlays;
  final double voiceCueVolume;
  final double voiceCueRate;
  final bool maleVoiceEnabled;
  final bool countdownBeepsEnabled;
  final bool transitionSirenEnabled;
  final bool musicDuckingEnabled;

  static AppSettings defaults() {
    return AppSettings(
      config: WorkoutConfig.defaults,
      voiceCueEnabled: true,
      hapticCueEnabled: true,
      muteVoiceWhileMusicPlays: true,
      voiceCueVolume: 1.0,
      voiceCueRate: 0.52,
      maleVoiceEnabled: true,
      countdownBeepsEnabled: true,
      transitionSirenEnabled: true,
      musicDuckingEnabled: true,
    );
  }
}
```

- [ ] **Step 2: Add SharedPreferences keys**

At the bottom of `settings_service.dart`, add:

```dart
const _kMaleVoiceEnabled = 'settings.maleVoiceEnabled';
const _kCountdownBeepsEnabled = 'settings.countdownBeepsEnabled';
const _kTransitionSirenEnabled = 'settings.transitionSirenEnabled';
const _kMusicDuckingEnabled = 'settings.musicDuckingEnabled';
```

- [ ] **Step 3: Update the load() method**

In the `load()` method, add to the AppSettings constructor call:

```dart
return AppSettings(
  config: config,
  voiceCueEnabled: prefs.getBool(_kVoiceCueEnabled) ?? defaults.voiceCueEnabled,
  hapticCueEnabled: prefs.getBool(_kHapticCueEnabled) ?? defaults.hapticCueEnabled,
  muteVoiceWhileMusicPlays:
      prefs.getBool(_kMuteVoiceWhileMusicPlays) ?? defaults.muteVoiceWhileMusicPlays,
  voiceCueVolume: prefs.getDouble(_kVoiceCueVolume) ?? defaults.voiceCueVolume,
  voiceCueRate: prefs.getDouble(_kVoiceCueRate) ?? defaults.voiceCueRate,
  maleVoiceEnabled: prefs.getBool(_kMaleVoiceEnabled) ?? defaults.maleVoiceEnabled,
  countdownBeepsEnabled: prefs.getBool(_kCountdownBeepsEnabled) ?? defaults.countdownBeepsEnabled,
  transitionSirenEnabled: prefs.getBool(_kTransitionSirenEnabled) ?? defaults.transitionSirenEnabled,
  musicDuckingEnabled: prefs.getBool(_kMusicDuckingEnabled) ?? defaults.musicDuckingEnabled,
);
```

- [ ] **Step 4: Update the save() method**

In the `save()` method, add:

```dart
await prefs.setBool(_kMaleVoiceEnabled, settings.maleVoiceEnabled);
await prefs.setBool(_kCountdownBeepsEnabled, settings.countdownBeepsEnabled);
await prefs.setBool(_kTransitionSirenEnabled, settings.transitionSirenEnabled);
await prefs.setBool(_kMusicDuckingEnabled, settings.musicDuckingEnabled);
```

- [ ] **Step 5: Verify no analysis errors**

```bash
flutter analyze lib/services/settings_service.dart
```

Expected: No errors. May have warnings about unused fields until they are consumed.

- [ ] **Step 6: Commit**

```bash
git add lib/services/settings_service.dart
git commit -m "feat: add premium audio settings to AppSettings and SettingsService"
```

---

### Task 6: Create AudioEngine

**Files:**
- Create: `lib/services/audio_engine.dart`

**Interfaces:**
- Consumes: `VoiceService` (Task 3), `SfxService` (Task 4), `MusicService` (existing)
- Produces: `AudioEngine` class with the same public API as old CueService

- [ ] **Step 1: Create AudioEngine**

Create `lib/services/audio_engine.dart`:

```dart
import 'package:flutter/foundation.dart';
import 'package:my_app/services/voice_service.dart';
import 'package:my_app/services/sfx_service.dart';
import 'package:my_app/services/music_service.dart';

class AudioEngine {
  AudioEngine({
    VoiceService? voiceService,
    SfxService? sfxService,
    MusicService? musicService,
  })  : _voice = voiceService ?? VoiceService(),
        _sfx = sfxService ?? SfxService(),
        _music = musicService;

  final VoiceService _voice;
  final SfxService _sfx;
  final MusicService? _music;

  bool _maleVoiceEnabled = true;
  bool _countdownBeepsEnabled = true;
  bool _transitionSirenEnabled = true;
  bool _musicDuckingEnabled = true;
  double _voiceVolume = 0.8;
  double _speechRate = 0.52;

  bool get supportsVoiceCues => _voice.supportsVoice;

  Future<void> initialize() async {
    await _voice.initialize();
    await _sfx.initialize();
  }

  Future<void> updateSettings({
    bool? maleVoiceEnabled,
    bool? countdownBeepsEnabled,
    bool? transitionSirenEnabled,
    bool? musicDuckingEnabled,
    double? voiceVolume,
    double? speechRate,
  }) async {
    if (maleVoiceEnabled != null) _maleVoiceEnabled = maleVoiceEnabled;
    if (countdownBeepsEnabled != null) _countdownBeepsEnabled = countdownBeepsEnabled;
    if (transitionSirenEnabled != null) _transitionSirenEnabled = transitionSirenEnabled;
    if (musicDuckingEnabled != null) _musicDuckingEnabled = musicDuckingEnabled;
    if (voiceVolume != null) _voiceVolume = voiceVolume.clamp(0.0, 1.0);
    if (speechRate != null) _speechRate = speechRate.clamp(0.2, 0.8);

    await _voice.updateSettings(volume: _voiceVolume, speechRate: _speechRate);
  }

  Future<void> announceExercise(String exerciseText, {bool shouldSpeak = true}) async {
    if (!_maleVoiceEnabled || !shouldSpeak) return;
    final text = exerciseText.trim();
    if (text.isEmpty) return;

    await _voice.speakCustom('Next exercise: $text.');
  }

  Future<void> announceRest({bool shouldSpeak = true}) async {
    if (!_maleVoiceEnabled || !shouldSpeak) return;
    await _voice.speakPrompt('rest');
  }

  Future<void> announcePhase(String phaseLabel) async {
    await announceExercise(phaseLabel);
  }

  Future<void> speakCount(int seconds, {bool shouldSpeak = true}) async {
    if (!_maleVoiceEnabled || !shouldSpeak || seconds < 1) return;
    await _voice.speakCustom('$seconds');
  }

  Future<void> announceCompletion() async {
    if (!_maleVoiceEnabled) return;
    await _voice.speakPrompt('great_job');
  }

  Future<void> playCountdownTick(int secondsRemaining) async {
    if (!_countdownBeepsEnabled) return;
    await _sfx.playCountdownTick(secondsRemaining);
  }

  Future<void> playCountdownFinalBeep() async {
    if (!_countdownBeepsEnabled) return;
    await _sfx.playCountdownFinalBeep();
  }

  Future<void> playPhaseCompletionBeep() async {
    // Phase 2: will play transition siren
  }

  Future<void> playWorkoutCompletionBeep() async {
    // Phase 2: will play victory sound
  }

  Future<void> duckMusic() async {
    if (!_musicDuckingEnabled) return;
    await _music?.duck();
  }

  Future<void> unduckMusic() async {
    if (!_musicDuckingEnabled) return;
    await _music?.unduck();
  }

  Future<void> stop() async {
    await _voice.stop();
    await _sfx.stop();
  }

  Future<void> dispose() async {
    await _voice.dispose();
    await _sfx.dispose();
  }
}

class AudioEngineException implements Exception {
  const AudioEngineException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/services/audio_engine.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/services/audio_engine.dart
git commit -m "feat: create AudioEngine orchestrator for voice + sfx + music ducking"
```

---

### Task 7: Create Audio Settings Page

**Files:**
- Create: `lib/pages/audio_settings_page.dart`

**Interfaces:**
- Consumes: `AppSettings` (Task 5), `SettingsService`
- Produces: Full-screen settings page with toggles and sliders

- [ ] **Step 1: Create AudioSettingsPage**

Create `lib/pages/audio_settings_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/services/settings_service.dart';

class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<AudioSettingsPage> createState() => _AudioSettingsPageState();
}

class _AudioSettingsPageState extends State<AudioSettingsPage> {
  late bool _maleVoiceEnabled;
  late double _voiceVolume;
  late double _speechRate;
  late bool _countdownBeepsEnabled;
  late bool _transitionSirenEnabled;
  late bool _musicDuckingEnabled;

  @override
  void initState() {
    super.initState();
    _maleVoiceEnabled = widget.settings.maleVoiceEnabled;
    _voiceVolume = widget.settings.voiceCueVolume;
    _speechRate = widget.settings.voiceCueRate;
    _countdownBeepsEnabled = widget.settings.countdownBeepsEnabled;
    _transitionSirenEnabled = widget.settings.transitionSirenEnabled;
    _musicDuckingEnabled = widget.settings.musicDuckingEnabled;
  }

  AppSettings _buildUpdated() {
    return AppSettings(
      config: widget.settings.config,
      voiceCueEnabled: widget.settings.voiceCueEnabled,
      hapticCueEnabled: widget.settings.hapticCueEnabled,
      muteVoiceWhileMusicPlays: widget.settings.muteVoiceWhileMusicPlays,
      voiceCueVolume: _voiceVolume,
      voiceCueRate: _speechRate,
      maleVoiceEnabled: _maleVoiceEnabled,
      countdownBeepsEnabled: _countdownBeepsEnabled,
      transitionSirenEnabled: _transitionSirenEnabled,
      musicDuckingEnabled: _musicDuckingEnabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: const Text(
            'Audio Settings',
            style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(_buildUpdated()),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          children: [
            _sectionHeader('VOICE COACH'),
            _switchTile(
              title: 'Male Voice',
              subtitle: 'Deep, confident voice coach',
              value: _maleVoiceEnabled,
              onChanged: (v) => setState(() => _maleVoiceEnabled = v),
            ),
            _sliderTile(
              title: 'Voice Volume',
              value: _voiceVolume,
              min: 0.0,
              max: 1.0,
              label: '${(_voiceVolume * 100).round()}%',
              onChanged: (v) => setState(() => _voiceVolume = v),
            ),
            _sliderTile(
              title: 'Speech Speed',
              value: _speechRate,
              min: 0.2,
              max: 0.8,
              label: '${_speechRate.toStringAsFixed(2)}x',
              onChanged: (v) => setState(() => _speechRate = v),
            ),
            const SizedBox(height: 24),
            _sectionHeader('SOUND EFFECTS'),
            _switchTile(
              title: 'Countdown Beeps',
              subtitle: 'Beeps during final 3 seconds',
              value: _countdownBeepsEnabled,
              onChanged: (v) => setState(() => _countdownBeepsEnabled = v),
            ),
            _switchTile(
              title: 'Transition Siren',
              subtitle: 'Sound between exercises',
              value: _transitionSirenEnabled,
              onChanged: (v) => setState(() => _transitionSirenEnabled = v),
            ),
            const SizedBox(height: 24),
            _sectionHeader('MUSIC'),
            _switchTile(
              title: 'Music Ducking',
              subtitle: 'Lower music during voice prompts',
              value: _musicDuckingEnabled,
              onChanged: (v) => setState(() => _musicDuckingEnabled = v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.white.withValues(alpha: 0.4),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _switchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
      subtitle: subtitle != null
          ? Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12))
          : null,
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFFFF8A1E),
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _sliderTile({
    required String title,
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: const Color(0xFFFF8A1E),
            inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
            thumbColor: const Color(0xFFFF8A1E),
            overlayColor: const Color(0x29FF8A1E),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Verify no analysis errors**

```bash
flutter analyze lib/pages/audio_settings_page.dart
```

Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/pages/audio_settings_page.dart
git commit -m "feat: create dedicated AudioSettingsPage with voice, sfx, and music toggles"
```

---

### Task 8: Wire AudioEngine into workout_timer_page.dart

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `AudioEngine` (Task 6), `AppSettings` (Task 5)
- Produces: Updated workout timer page using AudioEngine instead of CueService

This is the largest task. The changes are mechanical replacements.

- [ ] **Step 1: Replace CueService import and field**

In `workout_timer_page.dart`:
- Remove: `import 'package:my_app/services/cue_service.dart';`
- Add: `import 'package:my_app/services/audio_engine.dart';`
- Replace: `late final CueService _cueService;` → `late final AudioEngine _audioEngine;`

- [ ] **Step 2: Replace initialization**

In `initState()`:
- Replace: `_cueService = CueService();` → `_audioEngine = AudioEngine();`
- Replace: `_voiceCueEnabled = _cueService.supportsVoiceCues;` → `_voiceCueEnabled = _audioEngine.supportsVoiceCues;`
- Replace: `_cueService.updateSettings(...)` → `_audioEngine.updateSettings(...)`

- [ ] **Step 3: Replace dispose**

In `dispose()`:
- Replace: `_cueService.dispose();` → `_audioEngine.dispose();`

- [ ] **Step 4: Replace all _cueService calls in _handleWorkoutCues()**

Replace every occurrence in `_handleWorkoutCues()`:
- `_cueService.playPhaseCompletionBeep()` → `_audioEngine.playPhaseCompletionBeep()`
- `_cueService.announceRest(shouldSpeak: true)` → `_audioEngine.announceRest(shouldSpeak: true)`
- `_cueService.announceExercise(...)` → `_audioEngine.announceExercise(...)`
- `_cueService.playCountdownFinalBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.playCountdownTick(remaining)` → `_audioEngine.playCountdownTick(remaining)`
- `_cueService.speakCount(remaining, ...)` → `_audioEngine.speakCount(remaining, ...)`
- `_cueService.playWorkoutCompletionBeep()` → `_audioEngine.playWorkoutCompletionBeep()`
- `_cueService.announceCompletion()` → `_audioEngine.announceCompletion()`
- `CueServiceException` → `AudioEngineException`

- [ ] **Step 5: Replace _cueService.stop() calls**

Replace all `_cueService.stop()` → `_audioEngine.stop()`

- [ ] **Step 6: Replace _cueService.updateSettings() calls**

Replace `_cueService.updateSettings(...)` → `_audioEngine.updateSettings(...)`

- [ ] **Step 7: Verify no analysis errors**

```bash
flutter analyze lib/pages/workout_timer_page.dart
```

Expected: No errors. No references to CueService remaining.

- [ ] **Step 8: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "feat: wire AudioEngine into workout timer page replacing CueService"
```

---

### Task 9: Wire AudioEngine into workout_builder_player_page.dart

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `AudioEngine` (Task 6)
- Produces: Updated builder player page using AudioEngine instead of CueService

- [ ] **Step 1: Replace CueService import and field**

In `workout_builder_player_page.dart`:
- Remove: `import 'package:my_app/services/cue_service.dart';`
- Add: `import 'package:my_app/services/audio_engine.dart';`
- Replace: `final CueService _cueService = CueService();` → `final AudioEngine _audioEngine = AudioEngine();`

- [ ] **Step 2: Replace initialization**

Replace: `_cueService.updateSettings(...)` → `_audioEngine.updateSettings(...)`
Replace: `_voiceCueEnabled = _cueService.supportsVoiceCues && settings.voiceCueEnabled;` → `_voiceCueEnabled = _audioEngine.supportsVoiceCues && settings.voiceCueEnabled;`

- [ ] **Step 3: Replace dispose**

Replace: `_cueService.dispose();` → `_audioEngine.dispose();`

- [ ] **Step 4: Replace all _cueService calls in _handleWorkoutCues()**

Same mechanical replacements as Task 8:
- `_cueService.playPhaseCompletionBeep()` → `_audioEngine.playPhaseCompletionBeep()`
- `_cueService.announceRest(...)` → `_audioEngine.announceRest(...)`
- `_cueService.announceExercise(...)` → `_audioEngine.announceExercise(...)`
- `_cueService.playCountdownFinalBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.playCountdownBeep()` → `_audioEngine.playCountdownFinalBeep()`
- `_cueService.speakCount(...)` → `_audioEngine.speakCount(...)`
- `_cueService.playWorkoutCompletionBeep()` → `_audioEngine.playWorkoutCompletionBeep()`
- `_cueService.announceCompletion()` → `_audioEngine.announceCompletion()`
- `CueServiceException` → `AudioEngineException`

- [ ] **Step 5: Replace remaining _cueService calls**

Replace all `_cueService.stop()` → `_audioEngine.stop()`
Replace all `_cueService.updateSettings(...)` → `_audioEngine.updateSettings(...)`

- [ ] **Step 6: Verify no analysis errors**

```bash
flutter analyze lib/pages/workout_builder_player_page.dart
```

Expected: No errors. No references to CueService remaining.

- [ ] **Step 7: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat: wire AudioEngine into builder player page replacing CueService"
```

---

### Task 10: Delete old CueService

**Files:**
- Delete: `lib/services/cue_service.dart`

**Interfaces:**
- Consumes: Nothing (being deleted)
- Produces: Nothing (replaced by AudioEngine + VoiceService + SfxService)

- [ ] **Step 1: Verify no remaining references**

```bash
grep -r "cue_service\|CueService" lib/ --include="*.dart"
```

Expected: No results (all references replaced in Tasks 8 and 9).

- [ ] **Step 2: Delete the file**

```bash
rm lib/services/cue_service.dart
```

- [ ] **Step 3: Run full analysis**

```bash
flutter analyze lib/
```

Expected: No errors. No references to deleted file.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "feat: remove old CueService, replaced by AudioEngine architecture"
```

---

### Task 11: End-to-end verification

**Files:**
- None (verification only)

- [ ] **Step 1: Full project analysis**

```bash
flutter analyze lib/
```

Expected: No errors.

- [ ] **Step 2: Verify assets are bundled**

```bash
flutter build apk --debug 2>&1 | head -50
```

Expected: Build succeeds, no asset errors.

- [ ] **Step 3: Manual smoke test checklist**

Verify on a physical Android device:
1. Start a workout → voice says "Workout started. Let's go!"
2. Countdown 3→2→1 → hear escalating beeps (660Hz, 880Hz, 1100Hz)
3. Exercise ends → voice announces next exercise or rest
4. Workout completes → voice says "Great job!"
5. Open Audio Settings → all toggles and sliders work
6. Disable "Male Voice" → no voice prompts
7. Disable "Countdown Beeps" → no beeps
8. Music ducking lowers volume during voice prompts

- [ ] **Step 4: Final commit**

```bash
git add -A
git commit -m "feat: premium audio experience phase 1 complete"
```
