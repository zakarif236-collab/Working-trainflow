# Premium Audio System — Finalization Design

**Date:** 2026-07-24
**Status:** Approved
**Scope:** Rolling preloader, cache management, settings UI, performance audit, final QA

---

## Context

The premium audio system has working voice generation (Gemini API), local caching, countdown beeps, transition sounds, music ducking, and a device TTS fallback. However:
- No preloading ever happens in practice (neither workout page calls `preloadWorkout()`)
- `_isPreloaded` is always `false` — all voice goes through blocking `playClip()` or TTS
- The "Rebuild Current Workout" button is a no-op stub
- No per-workout metadata is exposed (name, size, date)
- Dead code exists (`_voiceVolume`)

This design addresses all remaining gaps to make the feature production-complete.

---

## 1. Rolling Voice Preloader

### Goal
Keep only 2 exercise clips + standard prompts in memory at any time. Dispose previous clips as the workout progresses.

### New API on AudioEngine

```dart
void setExerciseList(List<String> exerciseNames)
```
Called once when workout starts. Stores the list. Preloads clips for exercises 0 and 1 (if cache exists). Sets `_isPreloaded = true` if clips are available.

```dart
void onExerciseChanged(int currentIndex)
```
Called on each phase transition. `currentIndex` is the exercise index (0-based), NOT the phase index. Phase index includes warmup/rest/cooldown phases; exercise index is the sequential position in the exercise list. Disposes clip at `currentIndex-2` (if index >= 2). Preloads clip at `currentIndex+1` (if within bounds). Standard prompts are never disposed.

### Preloaded Clip Inventory
- **Permanent:** All standard prompts (12 clips: workout_started, warmup, begin, work, rest, recover, halfway_there, last_round, workout_complete, great_job, keep_going, excellent_work)
- **Rolling:** Current exercise clip + next exercise clip (2 clips max)

### Integration Points

**WorkoutTimerPage** (`lib/pages/workout_timer_page.dart`):
- In `_initializeFromSavedSettings()` or `didChangeDependencies()`: call `_audioEngine.setExerciseList(exerciseNames)` where `exerciseNames` is derived from `_controller.timeline` phases of type `WorkoutPhaseType.exercise`, extracting the exercise name from each phase
- In `_handleWorkoutCues()` on phase transition: call `_audioEngine.onExerciseChanged(phaseIndex)`

**WorkoutBuilderPlayerPage** (`lib/pages/workout_builder_player_page.dart`):
- Same pattern: `setExerciseList()` on init, `onExerciseChanged()` on phase change

### Memory Impact
- Standard prompts: ~12 clips × ~30KB avg = ~360KB
- 2 exercise clips: ~2 × ~30KB = ~60KB
- Total: ~420KB (vs current unbounded preloading)

---

## 2. Cache Manager — Per-Workout Metadata

### Goal
Expose per-workout cache info (name, size, date, clip count) for the settings UI.

### New Model

```dart
class CachedWorkoutInfo {
  final String fingerprint;
  final String name;
  final int sizeBytes;
  final DateTime generatedAt;
  final int clipCount;
}
```

Location: `lib/models/cached_workout_info.dart`

### New Method on GeminiVoiceService

```dart
Future<List<CachedWorkoutInfo>> getCachedWorkouts()
```

Implementation:
1. Iterate `_cacheRoot` subdirectories
2. For each: read `manifest.json`, parse `name`, `generatedAt`, `clips` list
3. Calculate directory size recursively
4. Return sorted by `generatedAt` descending (most recent first)
5. If manifest has no `name` field (legacy), show "Unnamed Workout"

### Manifest Change

Add `"name"` field to manifest.json:
```json
{
  "fingerprint": "A3B1C2D4",
  "name": "HIIT Blast",
  "generatedAt": "2026-07-24T10:30:00.000",
  "voiceModelVersion": "1.0",
  "clips": ["workout_started", "rest", "exercise_burpees", ...]
}
```

### generateAll() Change

Add optional `workoutName` parameter:
```dart
Future<void> generateAll({
  required String fingerprint,
  required List<String> exerciseNames,
  String? workoutName,
  void Function(double progress)? onProgress,
})
```

If `workoutName` is provided, store in manifest. If null, omit `name` field (legacy behavior).

### Delegation

AudioEngine exposes:
```dart
Future<List<CachedWorkoutInfo>> getCachedWorkouts() => _voice.getCachedWorkouts();
```

---

## 3. Settings UI — Per-Workout Cache Management

### Goal
Replace the simple "Cached Workouts: N" display with a list of individual cached workouts, each with Play/Rebuild/Delete actions.

### AudioSettingsPage Changes

**Constructor additions:**
```dart
final String? currentFingerprint;
final List<String>? currentExerciseNames;
final String? currentWorkoutName;
```

These are passed from the workout page so the "Rebuild" button knows which workout to rebuild.

**VOICE CACHE section redesign:**

```
Voice Cache (12.3 MB total)

┌─────────────────────────────────────┐
│ HIIT Blast                          │
│ 8 clips · 2.1 MB · Jul 24, 2026    │
│ [▶ Play]  [🔄 Rebuild]  [🗑 Delete]│
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Strength Builder                    │
│ 12 clips · 3.4 MB · Jul 23, 2026   │
│ [▶ Play]  [🔄 Rebuild]  [🗑 Delete]│
└─────────────────────────────────────┘

[Clear All Cache]
```

**Button behaviors:**

- **Play Preview:** Plays the first exercise clip (or `workout_started` if no exercise clips) as a preview
- **Rebuild:** Deletes the cache for that fingerprint, regenerates with current AI model, shows progress
- **Delete:** Deletes the cache for that fingerprint, refreshes the list

**"Rebuild Current Workout" button:** Replaced by per-workout Rebuild buttons. If `currentFingerprint` is provided, that workout appears at the top of the list with a "Current" badge.

### Navigation

Both workout pages pass their fingerprint/exercise names when navigating to AudioSettingsPage:
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => AudioSettingsPage(
      audioEngine: _audioEngine,
      settings: settings,
      onSettingsChanged: () {},
      currentFingerprint: _currentFingerprint,
      currentExerciseNames: _exerciseNames,
      currentWorkoutName: _workoutName,
    ),
  ),
);
```

---

## 4. Performance Audit

### Dead Code Cleanup
- Remove `_voiceVolume` field from AudioEngine (unused, line 64-65)
- Remove corresponding `updateSettings(voiceVolume:)` parameter handling

### AudioPlayer Lifecycle Audit
- `GeminiVoiceService._player`: Created in `initialize()`, never disposed → add `dispose()` method
- `GeminiVoiceService._clipPlayers`: Created in `preloadClips()`, disposed in `disposePreloadedClips()` → verify all paths dispose
- `AudioEngine.dispose()`: Verify calls `_voice.dispose()`, `_sfx.dispose()`
- `MusicService._player`: Already handled by `dispose()`

### No Duplicate Players
- `preloadClips()` already disposes all existing players before creating new ones
- Rolling preloader disposes old exercise clips before loading new ones
- Verify `playClip()` (non-preloaded path) uses the single shared `_player` — no duplicates

### Memory Leak Prevention
- `AudioEngine.stop()`: Clears queue, stops TTS, unducks music
- `AudioEngine.dispose()`: Clears queue, disposes voice and sfx
- Both workout pages call `_audioEngine.dispose()` in their `dispose()` methods
- Verify no orphaned timers or listeners reference disposed objects

---

## 5. Final QA Checklist

### Token Behavior
- [ ] Cached workouts never trigger Gemini API calls
- [ ] New workouts generate voice only once (incremental generation skips existing clips)
- [ ] Repeated workouts use cached audio (cache hit check in `preloadWorkout()`)

### Offline Behavior
- [ ] If cache exists: plays from cache (no network needed)
- [ ] If cache missing and AI unavailable: falls back to device TTS
- [ ] If cache missing and AI available: generates cache, then plays

### Audio Queue
- [ ] No overlapping announcements (sequential queue in AudioEngine)
- [ ] Queue clears on phase transition (existing behavior)

### Countdown Beeps
- [ ] 3 seconds: normal beep (660Hz)
- [ ] 2 seconds: normal beep (880Hz)
- [ ] 1 second: higher pitched beep (1100Hz)
- [ ] 0 seconds: transition sound (whoosh)

### Workout Flow
- [ ] Workout starts immediately after transition (no blocking on voice generation)
- [ ] Rolling preloader disposes old clips, loads new ones
- [ ] Standard prompts always available

---

## 6. Final Report Deliverables

After implementation, provide:
- Architecture diagram (text-based)
- Cache flow diagram (text-based)
- AI token flow diagram (text-based)
- Memory optimization summary
- Estimated RAM usage
- APK size impact
- Remaining technical debt
