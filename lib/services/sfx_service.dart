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
      final freq = 200 + t * 2000;
      final envelope = t < 0.1 ? t / 0.1 : (1.0 - t) / 0.9;
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
