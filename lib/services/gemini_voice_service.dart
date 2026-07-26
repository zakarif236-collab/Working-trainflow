import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:my_app/config/gemini_config.dart';
import 'package:my_app/models/cached_workout_info.dart';
import 'package:path_provider/path_provider.dart';

class GeminiVoiceService {
  AudioPlayer? _player;
  FlutterTts? _tts;
  bool _ttsInitialized = false;
  bool _initialized = false;
  String? _cacheRoot;
  final Map<String, AudioPlayer> _clipPlayers = {};

  bool get isReady => _initialized;

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

  Future<void> _saveManifest(String fingerprint, Set<String> clipNames, {String? name}) async {
    final manifest = <String, dynamic>{
      'fingerprint': fingerprint,
      'generatedAt': DateTime.now().toIso8601String(),
      'voiceModelVersion': '1.0',
      'clips': clipNames.toList(),
    };
    if (name != null) {
      manifest['name'] = name;
    }
    await File(_manifestPath(fingerprint)).writeAsString(jsonEncode(manifest));
  }

  Future<void> generateAll({
    required String fingerprint,
    required List<String> exerciseNames,
    String? workoutName,
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
        clipsToGenerate[key] = '$name.';
      }
    }

    for (final key in ['rest', 'recover', 'workout_complete']) {
      if (!allClipNames.contains(key)) {
        allClipNames.add(key);
        if (!existingClips.contains(key) && standardPrompts.containsKey(key)) {
          clipsToGenerate[key] = standardPrompts[key]!;
        }
      }
    }

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

    await _saveManifest(fingerprint, existingClips, name: workoutName);
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

  Future<void> _initTts() async {
    if (_ttsInitialized) return;
    try {
      _tts = FlutterTts();
      await _tts!.setLanguage('en-US');
      await _tts!.setSpeechRate(0.45);
      await _tts!.setVolume(1.0);
      await _tts!.setPitch(0.8);
      _ttsInitialized = true;
    } catch (_) {
      _tts = null;
    }
  }

  Future<void> speakFallback(String text) async {
    await _initTts();
    if (_tts == null) return;
    try {
      final completer = Completer<void>();
      _tts!.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      await _tts!.speak(text);
      await completer.future.timeout(const Duration(seconds: 3), onTimeout: () {});
    } catch (_) {}
  }

  Future<void> stopTts() async {
    if (_tts != null) {
      try {
        await _tts!.stop();
      } catch (_) {}
    }
  }

  Future<Uint8List?> _callGeminiTts(String text) async {
    if (!GeminiConfig.isConfigured) return null;

    final prompt = 'Generate audio of a deep, resonant, natural male voice saying: "$text". '
        'The voice should sound like a professional fitness coach — confident, '
        'calm, and motivational. Rich baritone tone, smooth delivery, '
        'clear enunciation. No robotic artifacts. No background noise.';

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
            'maxOutputTokens': 2048,
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

  Future<bool> playClip(String fingerprint, String clipName) async {
    final path = _clipPath(fingerprint, clipName);
    final file = File(path);
    if (!await file.exists()) return false;

    final player = _player;
    if (player == null) return false;

    try {
      await player.setFilePath(path);
      await player.play();
      await player.playerStateStream.firstWhere(
        (state) => state.processingState == ProcessingState.completed,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> preloadClips(String fingerprint, List<String> clipNames) async {
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
        try {
          await player.setFilePath(path);
          _clipPlayers[name] = player;
        } catch (_) {
          await player.dispose();
        }
      } catch (_) {}
    }
  }

  Future<bool> playPreloadedClip(String clipName) async {
    final player = _clipPlayers[clipName];
    if (player == null) return false;

    try {
      await player.seek(Duration.zero);
      await player.play();
      return true;
    } catch (_) {
      return false;
    }
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

  Future<List<CachedWorkoutInfo>> getCachedWorkouts() async {
    if (_cacheRoot == null) return [];
    final dir = Directory(_cacheRoot!);
    if (!await dir.exists()) return [];

    final workouts = <CachedWorkoutInfo>[];
    await for (final entity in dir.list()) {
      if (entity is! Directory) continue;
      final manifestFile = File('${entity.path}/manifest.json');
      if (!await manifestFile.exists()) continue;

      try {
        final raw = await manifestFile.readAsString();
        final decoded = jsonDecode(raw) as Map;
        final fp = decoded['fingerprint'] as String? ?? '';
        final name = decoded['name'] as String? ?? 'Unnamed Workout';
        final generatedAtStr = decoded['generatedAt'] as String?;
        final generatedAt = generatedAtStr != null
            ? DateTime.tryParse(generatedAtStr) ?? DateTime.now()
            : DateTime.now();
        final clips = decoded['clips'] as List? ?? [];

        int size = 0;
        await for (final f in entity.list(recursive: true)) {
          if (f is File) size += await f.length();
        }

        workouts.add(CachedWorkoutInfo(
          fingerprint: fp,
          name: name,
          sizeBytes: size,
          generatedAt: generatedAt,
          clipCount: clips.length,
        ));
      } catch (_) {}
    }

    workouts.sort((a, b) => b.generatedAt.compareTo(a.generatedAt));
    return workouts;
  }

  Future<void> clearCache() async {
    if (_cacheRoot == null) return;
    final dir = Directory(_cacheRoot!);
    if (await dir.exists()) {
      await dir.delete(recursive: true);
    }
    await initialize();
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
