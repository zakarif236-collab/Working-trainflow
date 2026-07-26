# Premium AI Voice Coach — Design

## Overview

Replace the robotic TTS voice experience with a premium AI voice coach powered by Gemini API. Generate natural, high-quality coaching speech on-demand, cache locally for instant playback, and add premium countdown beeps, transition sounds, and music ducking.

## Goals

- Gemini API generates deep, confident male fitness coach voice
- Local audio cache keyed by workout fingerprint (not name)
- Cache preloading before workout starts (zero delay during playback)
- Background generation with loading indicator (never block UI)
- Premium countdown beeps (escalating pitch) and transition whoosh
- Music ducking during voice announcements
- Audio queue — never two voice clips overlap
- Dedicated Audio Settings page with cache management
- Low token mode: retry → cache fallback → device TTS fallback
- Future-proof architecture for voice packs, languages, celebrities

## Constraints

- DO NOT modify workout logic, timer calculations, phase transitions, controllers
- DO NOT modify community system, workout builder, navigation, services, Firebase
- Only improve the audio presentation layer

## Architecture

### Service Split

```
AudioEngine (orchestrator)
├── GeminiVoiceService (Gemini API TTS + fingerprint cache)
├── SfxService (beeps, transition whoosh, victory sound)
└── MusicService (existing, ducking integration)
```

### AudioEngine (`lib/services/audio_engine.dart`)

Single entry point for all audio actions. Manages:
- Voice queue (sequential playback, never overlapping)
- Music ducking coordination (duck before voice, restore after)
- Cache preloading before workout starts
- Same public API as current CueService (call sites barely change)

Public API:
```dart
class AudioEngine {
  final GeminiVoiceService _voice;
  final SfxService _sfx;
  final MusicService? _music;

  // Preloading
  Future<void> preloadWorkout(WorkoutFingerprint fingerprint);
  bool get isPreloaded;

  // Core workout cues
  Future<void> announceExercise(String name, {bool shouldSpeak = true});
  Future<void> announceRest({bool shouldSpeak = true});
  Future<void> announcePhase(String label, {bool shouldSpeak = true});
  Future<void> speakCount(int seconds, {bool shouldSpeak = true});
  Future<void> announceCompletion();
  Future<void> announceWorkoutStarted();
  Future<void> announceWarmup();
  Future<void> announceBegin();
  Future<void> announceWork();
  Future<void> announceHalfwayThere();
  Future<void> announceLastRound();
  Future<void> announceGreatJob();
  Future<void> announceKeepGoing();
  Future<void> announceExcellentWork();

  // Sfx
  Future<void> playCountdownTick(int secondsRemaining);
  Future<void> playCountdownFinalBeep();
  Future<void> playTransitionWhoosh();
  Future<void> playVictorySound();

  // Music ducking (internal)
  Future<void> _duckMusic();
  Future<void> _unduckMusic();

  // Cache management
  Future<int> getCacheSizeBytes();
  Future<void> clearCache();
  Future<void> deleteWorkoutCache(String fingerprint);
  Future<void> rebuildCache(WorkoutFingerprint fingerprint);

  // Lifecycle
  Future<void> stop();
  Future<void> dispose();
  Future<void> updateSettings({...});
}
```

### GeminiVoiceService (`lib/services/gemini_voice_service.dart`)

Gemini API-powered TTS with fingerprint-based caching:
- Calls Gemini API with audio output modality
- Caches generated audio locally organized by workout fingerprint
- Falls back: retry → cache → device TTS → silence
- Prompts Gemini with coaching persona instruction

Gemini API call:
```dart
// NOTE: Exact API endpoint and parameters may need adjustment during implementation.
// Gemini's audio generation capabilities are evolving. If this doesn't work
// as expected, we'll fall back to using flutter_tts with enhanced settings
// (deeper pitch, slower rate) while keeping the same caching architecture.
final response = await http.post(
  Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-exp:generateContent?key=$apiKey'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({
    'contents': [{'parts': [{'text': 'Generate audio of a deep, confident male fitness coach saying: "$text". The voice should be energetic, motivational, and professional. Natural pacing, clear pronunciation.'}]}],
    'generationConfig': {'responseModalities': ['AUDIO', 'TEXT']}
  }),
);
```

### SfxService (`lib/services/sfx_service.dart`)

Sound effects:
- Countdown beeps: programmatically generated WAVs (improved sine waves with fade-out envelope)
- Transition whoosh: programmatically generated or bundled (300ms)
- Victory fanfare: programmatically generated or bundled (800ms)
- Pre-generates and caches beeps at init

## Workout Fingerprint

### Purpose

Never use workout name as cache key. Generate a deterministic fingerprint from workout content.

### Components

```dart
class WorkoutFingerprint {
  final String workoutId;
  final List<String> exerciseNames;
  final List<int> exerciseDurations;
  final List<int> restDurations;
  final List<int> recoveryDurations;
  final String voiceSelection;
  final String language;
  final String voiceModelVersion;

  String compute() {
    // SHA-256 hash of all components concatenated
    // Returns 8-char hex prefix (e.g., "7F29C1AA")
  }
}
```

### Cache Key Rules

- Fingerprint = SHA-256(workoutId + exerciseNames + exerciseOrder + exerciseDurations + restDurations + recoveryDurations + voiceSelection + language + voiceModelVersion)
- If fingerprint matches → use cached audio, never call AI
- If anything changes → generate new audio, new fingerprint

## Voice Cache

### Storage Structure

```
voice_cache/
├── index.json                    (fingerprint → metadata mapping)
├── 7F29C1AA/
│   ├── manifest.json             (list of clip filenames)
│   ├── workout_started.mp3
│   ├── burpees.mp3
│   ├── rest.mp3
│   ├── recover.mp3
│   ├── mountain_climbers.mp3
│   └── workout_complete.mp3
├── A3B8D2EF/
│   └── ...
└── ...
```

### manifest.json (per workout)
```json
{
  "fingerprint": "7F29C1AA",
  "generatedAt": "2026-07-24T10:30:00Z",
  "voiceModelVersion": "1.0",
  "clips": ["workout_started.mp3", "burpees.mp3", "rest.mp3", ...]
}
```

### index.json (global)
```json
{
  "7F29C1AA": {
    "generatedAt": "2026-07-24T10:30:00Z",
    "exerciseCount": 4,
    "totalSizeBytes": 48000
  },
  "A3B8D2EF": { ... }
}
```

## Cache Preloading

Before a workout starts:
1. Compute workout fingerprint
2. Check if cache exists for that fingerprint
3. If cache exists: load every voice clip into memory before countdown begins
4. Zero delay during playback — all clips ready in memory
5. If cache doesn't exist: generate in background (see Background Generation)

### Preloading Strategy (Performance)

- Preload only: current exercise voice + next exercise voice
- Dispose previous clips immediately after use
- Keep memory usage low — max 2-3 clips in memory at a time

## Background Generation

If a workout has never been generated:
1. Show loading indicator: "Preparing Voice Coach..."
2. Generate all voice clips in background (not blocking UI)
3. Generate once, save locally
4. Never regenerate for same fingerprint
5. Workout countdown begins only after generation completes

### Flow
```
User taps Start → Compute fingerprint → Cache hit?
  Yes → Preload clips → Start countdown (instant)
  No  → Show "Preparing Voice Coach..." → Generate all clips → Save to cache → Preload → Start countdown
```

## Low Token Mode

If AI generation fails:
1. Retry once (immediate retry)
2. If still unavailable → use cached voice (if exists for different fingerprint)
3. If no cache exists → fallback to device TTS (flutter_tts with enhanced settings)
4. The workout must always continue — never block or fail

### Fallback Chain
```
Gemini API → Retry once → Cached voice → Device TTS → Silence
```

## Voice Clips

### Standard Prompts

| Prompt Key | Text | Style |
|------------|------|-------|
| `workout_started` | "Workout started. Let's go!" | Energetic, commanding |
| `warmup` | "Warm up. Get ready." | Calm, preparatory |
| `begin` | "Begin!" | Sharp, powerful |
| `work` | "Work!" | Intense, driving |
| `rest` | "Rest." | Calm, controlled |
| `recover` | "Recover." | Calm, reassuring |
| `halfway_there` | "Halfway there!" | Motivational, upbeat |
| `last_round` | "Last round!" | Intense, push |
| `workout_complete` | "Workout complete!" | Satisfied, strong |
| `great_job` | "Great job!" | Enthusiastic |
| `keep_going` | "Keep going!" | Urgent, driving |
| `excellent_work` | "Excellent work." | Proud, final |

### Custom Exercise Names

For user-created exercises:
1. Gemini generates pronunciation audio
2. Cached locally under workout fingerprint directory
3. Never regenerated after first generation
4. Instant playback on subsequent uses

## Sound Effects

### Countdown Beeps (generated WAVs)

| Seconds remaining | Frequency | Duration | Volume | Style |
|---|---|---|---|---|
| 3 | 660 Hz | 150ms | 0.7 | Clean sine, slight fade-out |
| 2 | 880 Hz | 180ms | 0.85 | Sine + slight harmonic |
| 1 | 1100 Hz | 250ms | 1.0 | Bright sine, longer sustain |

Pre-generated at init and cached. Fade-out envelope prevents clicks.

### Transition Whoosh (bundled/generated)

- 300ms modern fitness transition sound
- NOT a siren. Think: air rise, digital whoosh, modern fitness cue
- Played at end of each exercise set, before announcing next phase
- Volume: 0.85 (always audible, never ducked)

### Victory Fanfare (bundled/generated)

- 800ms triumphant chord swell
- Played when workout completes, before "Workout complete!"
- Volume: 1.0

## Audio Mixing & Ducking

### Ducking Rules

| Event | Music Volume | Duration | Notes |
|-------|-------------|----------|-------|
| Voice announcement | 0.3 (duck) | While speaking + 500ms after | Restore to original volume |
| Countdown beeps (≤3s) | No duck | — | Beeps play over music at full volume |
| Transition whoosh | No duck | — | Whoosh plays over music at 0.85 |
| Victory fanfare | 0.2 (deep duck) | During fanfare + 1s | Then voice plays, then restore |

### Key Rules

1. Beeps and whoosh are never ducked — always audible over music
2. Only voice triggers ducking
3. Ducking is instant (no ramp), restore is instant
4. If music isn't playing, ducking is a no-op
5. Multiple rapid voice cues keep music ducked the entire time, unducking only after the last one

### Sequencing

**Phase transition:**
```
Exercise ends → Whoosh plays → 200ms gap → Voice announces next phase → 500ms → Music restores
```

**Countdown:**
```
3s: Beep (no duck)
2s: Beep (no duck)
1s: Final beep (no duck) → workout ends → Whoosh → Victory → Voice
```

## Audio Queue

Every voice announcement is queued:
```dart
class AudioQueue {
  final Queue<_AudioTask> _queue = Queue();
  bool _isPlaying = false;

  Future<void> enqueue(AudioTask task) async {
    _queue.add(task);
    if (!_isPlaying) _processQueue();
  }

  Future<void> _processQueue() async {
    if (_queue.isEmpty) {
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
  }
}
```

- Never allow two voice clips to overlap
- Always finish current announcement before starting next
- Workout cancellation clears the queue
- Voice always has priority over music

## Audio Settings

### Dedicated Settings Page

New file: `lib/pages/audio_settings_page.dart`

Accessible from the workout timer page's config panel.

### Layout

```
┌──────────────────────────────────────┐
│  Audio Settings                      │
├──────────────────────────────────────┤
│                                      │
│  VOICE COACH                         │
│  ├─ Voice Guidance       [ON]       │
│  ├─ Voice Volume     ═══●═══ 80%    │
│  └─ Speech Speed     ══●═════ 52%   │
│                                      │
│  SOUND EFFECTS                       │
│  ├─ Countdown Beeps      [ON]       │
│  └─ Transition Sound     [ON]       │
│                                      │
│  MUSIC                               │
│  └─ Music Ducking        [ON]       │
│                                      │
│  VOICE CACHE                         │
│  ├─ Cache Size: 2.4 MB              │
│  ├─ Cached Workouts: 3              │
│  ├─ Clear All Cache                 │
│  └─ Rebuild Current Workout         │
│                                      │
└──────────────────────────────────────┘
```

### Settings Storage

| Setting | SharedPreferences Key | Default | Type |
|---------|----------------------|---------|------|
| Voice Guidance | `settings.voiceCueEnabled` | `true` | bool |
| Voice Volume | `settings.voiceCueVolume` | `0.8` | double (0.0–1.0) |
| Speech Speed | `settings.voiceCueRate` | `0.52` | double (0.2–0.8) |
| Countdown Beeps | `settings.countdownBeepsEnabled` | `true` | bool |
| Transition Sound | `settings.transitionSoundEnabled` | `true` | bool |
| Music Ducking | `settings.musicDuckingEnabled` | `true` | bool |

### Removed from Inline ConfigPanel

- Voice Cue toggle → replaced by link to Audio Settings page
- Voice Volume slider → moved to Audio Settings page
- Voice Speed slider → moved to Audio Settings page
- Haptic Cue toggle → stays inline (not audio-related)

## Cache Management

### Settings Page Features

- **Voice Cache Size**: Display total cache size in MB
- **Cached Workouts**: Display number of cached workouts
- **Clear All Cache**: Delete entire `voice_cache/` directory
- **Delete Individual Workout**: Long-press to delete specific workout cache
- **Rebuild Cache**: Regenerate voice for current workout (useful after voice model update)

### Cache Lifecycle

1. Generated clips are stored under `voice_cache/<fingerprint>/`
2. `index.json` tracks all fingerprints and metadata
3. Cache is persistent across app restarts
4. Clearing cache removes all generated audio
5. Rebuilding cache regenerates audio for current workout

## Asset Structure

```
assets/audio/
└── sfx/
    ├── whoosh_transition.mp3    (generated or bundled)
    └── victory_fanfare.mp3      (generated or bundled)
```

Voice clips are NOT bundled — generated on-demand via Gemini API and cached locally by fingerprint.

### SFX Assets

The bundled sfx files need to be sourced. Options:
1. Generate via Gemini API (if it supports sound effects)
2. Use free SFX from a royalty-free library
3. Generate programmatically (like the beeps)
4. User provides their own files

During implementation, we'll generate simple programmatic SFX as a first pass, then optionally replace with higher-quality bundled assets.

## Performance

- Keep memory usage low
- Preload only: current exercise voice + next exercise voice
- Dispose previous clips immediately after use
- Max 2-3 clips in memory at a time
- Cache files are small MP3s (~5-15KB each)
- SFX beeps are pre-generated WAVs (~10KB each)

## Future Expansion

Architecture supports future additions with minimal changes:
- **Multiple AI voice packs**: Add voice pack ID to fingerprint, new voice pack = new cache
- **Multiple languages**: Add language code to fingerprint, new language = new cache
- **Celebrity voices**: Same architecture, different Gemini prompt or API
- **Offline voice packs**: Download pre-generated clip bundles, use instead of Gemini
- **Downloadable voice packs**: Store in `voice_packs/<pack_id>/`, reference from GeminiVoiceService

## Files Summary

### New files

- `lib/services/audio_engine.dart` — orchestrator + queue + ducking + preloading
- `lib/services/gemini_voice_service.dart` — Gemini API TTS + fingerprint cache
- `lib/services/sfx_service.dart` — beeps + whoosh + victory
- `lib/models/workout_fingerprint.dart` — fingerprint computation
- `lib/pages/audio_settings_page.dart` — settings UI + cache management
- `assets/audio/sfx/whoosh_transition.mp3` — transition sound
- `assets/audio/sfx/victory_fanfare.mp3` — victory sound

### Modified files

- `lib/pages/workout_timer_page.dart` — AudioEngine replaces CueService
- `lib/pages/workout_builder_player_page.dart` — AudioEngine replaces CueService
- `lib/services/settings_service.dart` — add new audio settings fields
- `lib/services/music_service.dart` — expose volume setter for ducking
- `pubspec.yaml` — add assets/audio/ to flutter assets

### Deleted files

- `lib/services/cue_service.dart` — replaced by AudioEngine + GeminiVoiceService + SfxService
