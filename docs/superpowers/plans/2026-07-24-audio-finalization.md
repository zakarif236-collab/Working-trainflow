# Premium Audio System — Finalization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete the premium audio system with smart rolling preloader, per-workout cache management, and performance hardening.

**Architecture:** AudioEngine manages a 2-exercise sliding window for voice clips. GeminiVoiceService stores workout names in manifests and exposes per-workout metadata. AudioSettingsPage displays individual cached workouts with Play/Rebuild/Delete actions.

**Tech Stack:** Flutter, Dart, just_audio, flutter_tts, Gemini API, path_provider

## Global Constraints

- DO NOT modify: WorkoutController, workout_models.dart, workout_timeline.dart, navigation, Firebase, auth
- Only improve audio presentation layer
- All new code must pass `flutter analyze` with zero errors
- Preserve existing public API surface of AudioEngine, GeminiVoiceService, SfxService

---

## Task 1: Create CachedWorkoutInfo Model

**Files:**
- Create: `lib/models/cached_workout_info.dart`

**Interfaces:**
- Consumes: none
- Produces: `CachedWorkoutInfo` class used by GeminiVoiceService and AudioSettingsPage

- [ ] **Step 1: Create the model file**

```dart
// lib/models/cached_workout_info.dart
class CachedWorkoutInfo {
  const CachedWorkoutInfo({
    required this.fingerprint,
    required this.name,
    required this.sizeBytes,
    required this.generatedAt,
    required this.clipCount,
  });

  final String fingerprint;
  final String name;
  final int sizeBytes;
  final DateTime generatedAt;
  final int clipCount;
}
```

- [ ] **Step 2: Verify no analysis errors**

Run: `flutter analyze lib/models/cached_workout_info.dart`
Expected: No issues found

---

## Task 2: Add getCachedWorkouts and workout name to GeminiVoiceService

**Files:**
- Modify: `lib/services/gemini_voice_service.dart`

**Interfaces:**
- Consumes: `CachedWorkoutInfo` from Task 1
- Produces: `getCachedWorkouts()`, updated `_saveManifest()`, updated `generateAll()`

- [ ] **Step 1: Add import for CachedWorkoutInfo**

At the top of `lib/services/gemini_voice_service.dart`, add:
```dart
import 'package:my_app/models/cached_workout_info.dart';
```

- [ ] **Step 2: Update _saveManifest to accept optional name**

Replace the `_saveManifest` method (lines 77-85) with:
```dart
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
```

- [ ] **Step 3: Update generateAll to accept and pass workoutName**

Replace the `generateAll` signature (line 87-91) and the `_saveManifest` call (line 144):

Signature becomes:
```dart
  Future<void> generateAll({
    required String fingerprint,
    required List<String> exerciseNames,
    String? workoutName,
    void Function(double progress)? onProgress,
  }) async {
```

Line 144 becomes:
```dart
    await _saveManifest(fingerprint, existingClips, name: workoutName);
```

- [ ] **Step 4: Add getCachedWorkouts method**

Add this method after `getCachedWorkoutCount()` (after line 345):
```dart
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
        final fingerprint = decoded['fingerprint'] as String? ?? '';
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
          fingerprint: fingerprint,
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
```

- [ ] **Step 5: Verify no analysis errors**

Run: `flutter analyze lib/services/gemini_voice_service.dart`
Expected: No issues found

---

## Task 3: Add rolling preloader to AudioEngine

**Files:**
- Modify: `lib/services/audio_engine.dart`

**Interfaces:**
- Consumes: `GeminiVoiceService.preloadClips()`, `GeminiVoiceService.disposePreloadedClips()`, `GeminiVoiceService.cacheExists()`
- Produces: `setExerciseList()`, `onExerciseChanged()`, `getCachedWorkouts()`, updated `rebuildCache()`

- [ ] **Step 1: Add CachedWorkoutInfo import**

```dart
import 'package:my_app/models/cached_workout_info.dart';
```

- [ ] **Step 2: Add rolling preloader state fields**

After line 67 (`bool _transitionSoundEnabled = true;`), add:
```dart
  List<String> _exerciseNames = [];
  int _currentExerciseIndex = -1;
```

- [ ] **Step 3: Remove dead _voiceVolume field**

Delete lines 64-65:
```dart
  // ignore: unused_field
  double _voiceVolume = 0.8;
```

And remove `voiceVolume` from `updateSettings` (line 77-87). The method becomes:
```dart
  void updateSettings({
    bool? countdownBeepsEnabled,
    bool? transitionSoundEnabled,
    bool? musicDuckingEnabled,
  }) {
    if (countdownBeepsEnabled != null) _countdownBeepsEnabled = countdownBeepsEnabled;
    if (transitionSoundEnabled != null) _transitionSoundEnabled = transitionSoundEnabled;
    if (musicDuckingEnabled != null) _musicDuckingEnabled = musicDuckingEnabled;
  }
```

- [ ] **Step 4: Add setExerciseList method**

Add after the `generateWorkoutVoice` method (after line 126):
```dart
  Future<void> setExerciseList(List<String> exerciseNames) async {
    _exerciseNames = List<String>.from(exerciseNames);
    _currentExerciseIndex = -1;

    final fp = _currentFingerprint;
    if (fp == null || !await _voice.cacheExists(fp)) {
      _isPreloaded = false;
      return;
    }

    // Preload standard prompts (permanent) + first 2 exercise clips
    final clipsToLoad = <String>[
      ...GeminiVoiceService.standardPrompts.keys,
    ];
    for (int i = 0; i < _exerciseNames.length && i < 2; i++) {
      clipsToLoad.add(_exerciseClipKey(_exerciseNames[i]));
    }

    await _voice.preloadClips(fp, clipsToLoad);
    _isPreloaded = true;
  }

  String _exerciseClipKey(String name) =>
      'exercise_${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
```

- [ ] **Step 5: Add onExerciseChanged method**

Add after `setExerciseList`:
```dart
  Future<void> onExerciseChanged(int currentIndex) async {
    if (currentIndex == _currentExerciseIndex) return;
    _currentExerciseIndex = currentIndex;

    final fp = _currentFingerprint;
    if (fp == null || !await _voice.cacheExists(fp)) return;

    // Build the set of clips that should be in memory:
    // standard prompts (permanent) + current exercise + next exercise
    final clipsToKeep = <String>[
      ...GeminiVoiceService.standardPrompts.keys,
    ];
    if (currentIndex < _exerciseNames.length) {
      clipsToKeep.add(_exerciseClipKey(_exerciseNames[currentIndex]));
    }
    if (currentIndex + 1 < _exerciseNames.length) {
      clipsToKeep.add(_exerciseClipKey(_exerciseNames[currentIndex + 1]));
    }

    await _voice.preloadClips(fp, clipsToKeep);
  }
```

- [ ] **Step 6: Add getCachedWorkouts delegation**

Add after `deleteWorkoutCache` (after line 233):
```dart
  Future<List<CachedWorkoutInfo>> getCachedWorkouts() => _voice.getCachedWorkouts();
```

- [ ] **Step 7: Update rebuildCache to accept optional workoutName**

Replace the `rebuildCache` method (lines 235-238):
```dart
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
    // Rebuild the rolling preload for current workout
    if (fingerprint.compute() == _currentFingerprint) {
      await setExerciseList(exerciseNames);
    }
  }
```

- [ ] **Step 8: Update generateWorkoutVoice to pass workoutName**

Update the `generateWorkoutVoice` method to accept and pass `workoutName`:
```dart
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
```

- [ ] **Step 9: Verify no analysis errors**

Run: `flutter analyze lib/services/audio_engine.dart`
Expected: No issues found (info-level lints about initializing_formals are acceptable)

---

## Task 4: Wire rolling preloader into WorkoutTimerPage

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `AudioEngine.setExerciseList()`, `AudioEngine.onExerciseChanged()`
- Produces: calls into AudioEngine on workout start and phase transitions

- [ ] **Step 1: Add _exerciseNames tracking field**

In the `_WorkoutTimerPageState` class, near the other state fields (around line 88), add:
```dart
  List<String> _exerciseNames = [];
```

- [ ] **Step 2: Add _buildExerciseNames helper method**

Add a helper method to extract exercise names from the timeline:
```dart
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
```

- [ ] **Step 3: Call setExerciseList after AudioEngine initialization**

In `_initializeFromSavedSettings()`, after `_audioEngine.initialize()` (line 512), add:
```dart
      _exerciseNames = _buildExerciseNames();
      if (_exerciseNames.isNotEmpty) {
        await _audioEngine.setExerciseList(_exerciseNames);
      }
```

- [ ] **Step 4: Call onExerciseChanged on phase transitions**

In `_handleWorkoutCues()`, inside the phase transition block (around line 580, after `final phase = _controller.currentPhase;`), add:
```dart
        // Track exercise index for rolling preloader
        int exerciseIndex = 0;
        for (int i = 0; i < phaseIndex; i++) {
          if (_controller.timeline[i].type == WorkoutPhaseType.work) {
            exerciseIndex++;
          }
        }
        await _audioEngine.onExerciseChanged(exerciseIndex);
```

- [ ] **Step 5: Pass current workout info to AudioSettingsPage navigation**

Find the AudioSettingsPage navigation in the _ConfigPanel (around line 2238). Update it to pass current workout info. The _ConfigPanel needs new constructor parameters:

Add to _ConfigPanel constructor:
```dart
    required this.currentFingerprint,
    required this.currentExerciseNames,
```

Add fields:
```dart
  final String? currentFingerprint;
  final List<String> currentExerciseNames;
```

Update the navigation call:
```dart
              builder: (_) => AudioSettingsPage(
                audioEngine: audioEngine,
                settings: settings,
                onSettingsChanged: () {},
                currentFingerprint: currentFingerprint,
                currentExerciseNames: currentExerciseNames,
              ),
```

Update the _ConfigPanel instantiation (around line 1109) to pass:
```dart
        currentFingerprint: _audioEngine.currentFingerprint,
        currentExerciseNames: _exerciseNames,
```

- [ ] **Step 6: Verify no analysis errors**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No issues found

---

## Task 5: Wire rolling preloader into WorkoutBuilderPlayerPage

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `AudioEngine.setExerciseList()`, `AudioEngine.onExerciseChanged()`
- Produces: calls into AudioEngine on workout start and phase transitions

- [ ] **Step 1: Add _exerciseNames tracking field**

In the `_WorkoutBuilderPlayerPageState` class, add:
```dart
  List<String> _exerciseNames = [];
```

- [ ] **Step 2: Add _buildExerciseNames helper method**

```dart
  List<String> _buildExerciseNames() {
    final names = <String>[];
    for (final phase in _phases) {
      if (phase.type == _BuilderPhaseType.work) {
        if (!names.contains(phase.exercise.name)) {
          names.add(phase.exercise.name);
        }
      }
    }
    return names;
  }
```

- [ ] **Step 3: Call setExerciseList after AudioEngine initialization**

In `_initializeCueSettings()`, after `_audioEngine.initialize()`, add:
```dart
      _exerciseNames = _buildExerciseNames();
      if (_exerciseNames.isNotEmpty) {
        await _audioEngine.setExerciseList(_exerciseNames);
      }
```

- [ ] **Step 4: Call onExerciseChanged on phase transitions**

In `_handleWorkoutCues()`, inside the phase transition block (around line 185), add:
```dart
        await _audioEngine.onExerciseChanged(current.exerciseIndex);
```

- [ ] **Step 5: Pass current workout info to AudioSettingsPage navigation**

Find the AudioSettingsPage navigation (around line 520). Update it:
```dart
              builder: (_) => AudioSettingsPage(
                audioEngine: _audioEngine,
                settings: AppSettings.defaults(),
                onSettingsChanged: () {},
                currentFingerprint: _audioEngine.currentFingerprint,
                currentExerciseNames: _exerciseNames,
              ),
```

- [ ] **Step 6: Verify no analysis errors**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

---

## Task 6: Update AudioSettingsPage with per-workout cache list

**Files:**
- Modify: `lib/pages/audio_settings_page.dart`

**Interfaces:**
- Consumes: `AudioEngine.getCachedWorkouts()`, `AudioEngine.rebuildCache()`, `AudioEngine.deleteWorkoutCache()`, `CachedWorkoutInfo`
- Produces: full settings UI with per-workout list

- [ ] **Step 1: Add imports**

```dart
import 'package:my_app/models/cached_workout_info.dart';
import 'package:my_app/models/workout_fingerprint.dart';
```

- [ ] **Step 2: Add constructor parameters for current workout**

Update the AudioSettingsPage constructor:
```dart
class AudioSettingsPage extends StatefulWidget {
  const AudioSettingsPage({
    super.key,
    required this.audioEngine,
    required this.settings,
    required this.onSettingsChanged,
    this.currentFingerprint,
    this.currentExerciseNames,
  });

  final AudioEngine audioEngine;
  final AppSettings settings;
  final VoidCallback onSettingsChanged;
  final String? currentFingerprint;
  final List<String>? currentExerciseNames;
```

- [ ] **Step 3: Replace cache state variables**

Replace `_cacheSizeBytes` and `_cachedWorkouts` with:
```dart
  List<CachedWorkoutInfo> _cachedWorkouts = [];
  int _cacheSizeBytes = 0;
```

- [ ] **Step 4: Update _loadCacheInfo**

Replace the `_loadCacheInfo` method:
```dart
  Future<void> _loadCacheInfo() async {
    final workouts = await widget.audioEngine.getCachedWorkouts();
    final size = await widget.audioEngine.getCacheSizeBytes();
    if (mounted) {
      setState(() {
        _cachedWorkouts = workouts;
        _cacheSizeBytes = size;
      });
    }
  }
```

- [ ] **Step 5: Replace the VOICE CACHE section**

Replace the entire VOICE CACHE section (lines 130-163) with:
```dart
          _buildSection(
            'VOICE CACHE',
            [
              ListTile(
                title: const Text('Total Cache Size', style: TextStyle(color: Colors.white70)),
                trailing: Text(_formatBytes(_cacheSizeBytes), style: const TextStyle(color: Colors.white54)),
              ),
              if (_cachedWorkouts.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No cached workouts', style: TextStyle(color: Colors.white38)),
                ),
              for (final workout in _cachedWorkouts)
                _buildWorkoutCacheCard(workout),
              const Divider(color: Colors.white12),
              ListTile(
                title: const Text('Clear All Cache', style: TextStyle(color: Color(0xFFEF4444))),
                onTap: () async {
                  await widget.audioEngine.clearCache();
                  await _loadCacheInfo();
                  if (!mounted || !context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cache cleared')),
                  );
                },
              ),
            ],
          ),
```

- [ ] **Step 6: Add _buildWorkoutCacheCard method**

Add after the `_buildSlider` method:
```dart
  Widget _buildWorkoutCacheCard(CachedWorkoutInfo workout) {
    final isCurrent = workout.fingerprint == widget.currentFingerprint;
    final dateStr = '${workout.generatedAt.month}/${workout.generatedAt.day}/${workout.generatedAt.year}';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: isCurrent ? 0.08 : 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent ? const Color(0xFF22C55E).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  workout.name,
                  style: TextStyle(
                    color: isCurrent ? const Color(0xFF22C55E) : Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isCurrent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('CURRENT', style: TextStyle(color: Color(0xFF22C55E), fontSize: 10, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${workout.clipCount} clips · ${_formatBytes(workout.sizeBytes)} · $dateStr',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildCacheAction(
                icon: Icons.play_arrow_rounded,
                label: 'Play',
                color: const Color(0xFF22C55E),
                onTap: () => _previewWorkout(workout),
              ),
              const SizedBox(width: 12),
              _buildCacheAction(
                icon: Icons.refresh_rounded,
                label: 'Rebuild',
                color: const Color(0xFFF59E0B),
                onTap: () => _rebuildWorkout(workout),
              ),
              const SizedBox(width: 12),
              _buildCacheAction(
                icon: Icons.delete_outline_rounded,
                label: 'Delete',
                color: const Color(0xFFEF4444),
                onTap: () => _deleteWorkout(workout),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCacheAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Future<void> _previewWorkout(CachedWorkoutInfo workout) async {
    await widget.audioEngine.previewWorkoutClip(workout.fingerprint);
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playing preview: ${workout.name}')),
    );
  }

  Future<void> _rebuildWorkout(CachedWorkoutInfo workout) async {
    if (widget.currentExerciseNames == null || widget.currentExerciseNames!.isEmpty) {
      if (!mounted || !context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No workout data available for rebuild')),
      );
      return;
    }
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rebuilding: ${workout.name}...')),
    );
    await widget.audioEngine.rebuildCache(
      WorkoutFingerprint(
        workoutId: workout.fingerprint,
        exerciseNames: widget.currentExerciseNames!,
        exerciseDurations: [],
        restDurations: [],
        recoveryDurations: [],
      ),
      widget.currentExerciseNames!,
      workoutName: workout.name,
    );
    await _loadCacheInfo();
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Rebuilt: ${workout.name}')),
    );
  }

  Future<void> _deleteWorkout(CachedWorkoutInfo workout) async {
    await widget.audioEngine.deleteWorkoutCache(workout.fingerprint);
    await _loadCacheInfo();
    if (!mounted || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted: ${workout.name}')),
    );
  }
```

- [ ] **Step 7: Add previewWorkoutClip to AudioEngine**

In `lib/services/audio_engine.dart`, add after `deleteWorkoutCache`:
```dart
  Future<void> previewWorkoutClip(String fingerprint) async {
    if (await _voice.cacheExists(fingerprint)) {
      await _voice.playClip(fingerprint, 'workout_started');
    }
  }
```

- [ ] **Step 8: Remove voiceVolume from AudioSettingsPage**

Remove the voice volume slider from the VOICE COACH section (lines 91-95) since it was dead code:
```dart
              _buildSlider('Voice Volume', _voiceVolume, (v) {
                setState(() => _voiceVolume = v);
                widget.audioEngine.updateSettings(voiceVolume: v);
                widget.onSettingsChanged();
              }),
```

Also remove `_voiceVolume` from the state fields and initState.

- [ ] **Step 9: Verify no analysis errors**

Run: `flutter analyze lib/pages/audio_settings_page.dart lib/services/audio_engine.dart`
Expected: No issues found

---

## Task 7: Performance audit and cleanup

**Files:**
- Modify: `lib/services/audio_engine.dart`
- Modify: `lib/services/gemini_voice_service.dart`

**Interfaces:**
- Consumes: existing disposal patterns
- Produces: verified clean disposal chain

- [ ] **Step 1: Verify AudioEngine.dispose() is complete**

Check that `dispose()` calls:
- `_voiceQueue.clear()`
- `_voice.dispose()` (which disposes `_player` and all `_clipPlayers`)
- `_sfx.dispose()`

Current code (lines 251-255) is correct. No changes needed.

- [ ] **Step 2: Verify GeminiVoiceService.dispose() is complete**

Check that `dispose()` calls:
- `_player?.dispose()`
- All `_clipPlayers.values` disposed
- `_clipPlayers.clear()`
- `_player = null`
- `_initialized = false`

Current code (lines 367-375) is correct. No changes needed.

- [ ] **Step 3: Verify no duplicate AudioPlayers**

- `initialize()` creates one `_player` (line 45)
- `preloadClips()` disposes all existing `_clipPlayers` before creating new ones (lines 280-283)
- `disposePreloadedClips()` disposes all `_clipPlayers` (lines 311-316)
- Rolling preloader calls `preloadClips()` which handles cleanup automatically

No duplicates found. No changes needed.

- [ ] **Step 4: Verify MusicService disposal in workout pages**

Both workout pages call `_musicService.dispose()` in their `dispose()` methods. AudioEngine's `dispose()` does NOT dispose `_music` (correct — it doesn't own it).

- [ ] **Step 5: Run full analysis**

Run: `flutter analyze lib/`
Expected: Only info-level lints (prefer_initializing_formals), zero errors, zero warnings

---

## Task 8: Final QA verification

**Files:**
- Read-only verification across all modified files

- [ ] **Step 1: Verify cached workouts never trigger Gemini API**

Check `preloadWorkout()` — only calls `preloadClips()` (disk read), never `generateAll()` (API call).
Check `onExerciseChanged()` — only calls `preloadClips()` (disk read).

- [ ] **Step 2: Verify new workouts generate voice only once**

Check `generateAll()` — skips clips that already exist in manifest (lines 106, 114).

- [ ] **Step 3: Verify repeated workouts use cached audio**

Check `preloadWorkout()` — calls `cacheExists()` first, only preloads if cache exists.

- [ ] **Step 4: Verify offline mode uses cache**

Check `_speakClip()` — if `_isPreloaded` is true, plays from memory. If false, tries `playClip()` (disk). If both fail, falls back to device TTS.

- [ ] **Step 5: Verify no overlapping announcements**

Check `_AudioQueue` — processes tasks sequentially, one at a time.

- [ ] **Step 6: Verify countdown beeps**

Check `SfxService.playCountdownTick()`:
- 3 seconds: 660Hz, 0.7 volume
- 2 seconds: 880Hz, 0.85 volume
- 1 second: 1100Hz, 1.0 volume

Check `SfxService.playTransitionWhoosh()` for 0-second transition.

- [ ] **Step 7: Verify workout starts immediately**

Check that `generateWorkoutVoice()` runs in background (called from settings, not from timer start). Timer starts regardless of voice generation status.

- [ ] **Step 8: Run full analysis one final time**

Run: `flutter analyze lib/`
Expected: Zero errors, zero warnings

---

## Task 9: Final report

**Files:**
- Create: `docs/superpowers/reports/2026-07-24-audio-finalization-report.md`

- [ ] **Step 1: Write the final report**

Include:
- Architecture diagram (text-based)
- Cache flow diagram
- AI token flow diagram
- Memory optimization summary
- Estimated RAM usage
- APK size impact
- Remaining technical debt
