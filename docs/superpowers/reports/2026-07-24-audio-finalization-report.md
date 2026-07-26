# Premium Audio System — Finalization Report

**Date:** 2026-07-24
**Status:** Complete

---

## 1. Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI Layer                                  │
│  WorkoutTimerPage / WorkoutBuilderPlayerPage / AudioSettingsPage │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│                       AudioEngine                                │
│  • Orchestrates all audio playback                               │
│  • Manages voice queue (serialized playback)                     │
│  • Rolling preloader: 2 exercise clips + standard prompts        │
│  • Music ducking control                                         │
│  • Settings relay (beeps, transitions, ducking)                  │
└───────┬──────────────────┬──────────────────┬───────────────────┘
        │                  │                  │
        ▼                  ▼                  ▼
┌───────────────┐  ┌──────────────┐  ┌────────────────┐
│ GeminiVoice   │  │ SfxService   │  │ MusicService   │
│ Service       │  │              │  │ (external)     │
│               │  │              │  │                │
│ • Gemini TTS  │  │ • Sine wave  │  │ • AudioPlayer  │
│   API calls   │  │   beeps      │  │ • Duck/unduck  │
│ • Disk cache  │  │ • Whoosh     │  └────────────────┘
│   (per-fp)    │  │ • Victory    │
│ • Preloaded   │  │   fanfare    │
│   AudioPlayers│  │ • Programmatic│
│ • Device TTS  │  │   WAV gen    │
│   fallback    │  │ • 0 preload  │
│ • flutter_tts │  │   cost       │
└───────────────┘  └──────────────┘

Data Models:
┌──────────────────────┐  ┌────────────────────────┐
│ WorkoutFingerprint   │  │ CachedWorkoutInfo      │
│ • SHA-256 hash       │  │ • fingerprint, name    │
│ • 8-char hex key     │  │ • sizeBytes, clipCount │
│ • exercise/duration  │  │ • generatedAt          │
│   voice/lang inputs  │  └────────────────────────┘
└──────────────────────┘
```

**Key design decisions:**
- AudioEngine is the single entry point — UI never talks to GeminiVoiceService or SfxService directly.
- `_AudioQueue` serializes voice announcements to prevent overlapping speech.
- GeminiVoiceService owns both the Gemini API client and the disk cache (one service, one responsibility boundary: "voice audio").
- SfxService generates WAV files on-the-fly — zero preloaded assets, zero network calls.

---

## 2. Cache Flow Diagram

```
Workout Starts
      │
      ▼
setExerciseList(exerciseNames)
      │
      ├── Cache exists? ──No──► _isPreloaded = false
      │         │                      │
      │        Yes                     │
      │         │                      │
      ▼         ▼                      ▼
  Load standard prompts          No preloading
  + first 2 exercise clips       (fallback to device TTS
  into AudioPlayers              on each announcement)
      │
      ▼
  ┌──────────────────────────────────────┐
  │         Phase Transitions             │
  │                                       │
  │  onExerciseChanged(currentIndex)      │
  │         │                             │
  │         ▼                             │
  │  Dispose old clip players             │
  │  Preload current + next exercise      │
  │  + standard prompts                   │
  └──────────────────────────────────────┘
      │
      ▼
  ┌──────────────────────────────────────┐
  │         Playback Decision             │
  │                                       │
  │  _speakClip(clipName)                 │
  │         │                             │
  │  Preloaded? ──Yes──► playPreloadedClip│
  │         │                (memory)     │
  │        No                            │
  │         │                             │
  │  Cache hit? ──Yes──► playClip(fp)     │
  │         │             (disk read)     │
  │        No                            │
  │         │                             │
  │  Gemini API ──retry──► Device TTS     │
  │         │              (flutter_tts)  │
  │        Fail                          │
  │         │                             │
  │         ▼                             │
  │      Silence                         │
  └──────────────────────────────────────┘
```

**Fallback chain:** Preloaded → Disk → Gemini API → Device TTS → Silence

---

## 3. AI Token Flow Diagram

```
FIRST WORKOUT (no cache)
─────────────────────────────────
WorkoutFingerprint.compute()
        │
        ▼
cacheExists(fingerprint) → false
        │
        ▼
generateAll()
  ├─ 12 standard prompts  → Gemini API call each
  ├─ N exercise clips      → Gemini API call each
  └─ Total: (12 + N) API calls
        │
        ▼
  Tokens consumed: YES
  Manifest saved: manifest.json
  Clips saved:     *.mp3


REPEATED WORKOUT (cache exists)
─────────────────────────────────
WorkoutFingerprint.compute()
        │
        ▼
cacheExists(fingerprint) → true
        │
        ▼
preloadClips() from disk
        │
        ▼
  Tokens consumed: 0 (no API calls)


REBUILD (user clicks "Rebuild")
─────────────────────────────────
deleteWorkoutCache(fingerprint)
        │
        ▼
generateAll() (same as first workout)
        │
        ▼
  Tokens consumed: YES (regenerated)
  Cache refreshed with new clips
```

**Token cost per workout:**
- 12 standard prompts + N exercise clips = `(12 + N)` API calls
- Typical workout (8 exercises): 20 calls
- Typical workout (20 exercises): 32 calls
- Repeated workouts: 0 calls

---

## 4. Memory Optimization Summary

| Metric | Before (Unbounded) | After (Rolling Window) | Improvement |
|--------|-------------------|----------------------|-------------|
| Standard prompts | ~12 clips × ~30KB = ~360KB | ~360KB (permanent) | Same |
| Exercise clips | ALL clips in memory | 2 × ~30KB = ~60KB | **90%+** |
| Peak per workout (20 exercises) | ~12 + 20 = 32 clips = ~960KB | ~360 + 60 = ~420KB | **56%** |
| Peak per workout (50 exercises) | ~12 + 50 = 62 clips = ~1.86MB | ~360 + 60 = ~420KB | **77%** |
| Long workout (100 exercises) | ~3.36MB | ~420KB | **87%** |
| Theoretical worst case | 10+ MB | ~420KB | **96%+** |

**Key mechanism:** `onExerciseChanged()` disposes previous clip players and preloads only the current + next exercise. Standard prompts are always kept resident.

---

## 5. Estimated RAM Usage

| Component | RAM Footprint | Notes |
|-----------|--------------|-------|
| AudioEngine | <1 KB | State management, queue, settings flags |
| GeminiVoiceService | ~60 KB typical | 1 shared `AudioPlayer` + N preloaded `AudioPlayer` instances (~2–5KB each) |
| SfxService | ~2 KB | 1 `AudioPlayer`, generates WAV in-place |
| MusicService | ~5 KB | 1 `AudioPlayer` for background music |
| Device TTS (flutter_tts) | ~5 MB | Platform-specific TTS engine (only when initialized) |
| **Total audio subsystem** | **~6–8 MB** | Most from flutter_tts; Gemini + Sfx <70KB |

**Notes:**
- flutter_tts is lazy-initialized (only on first fallback need).
- GeminiVoiceService preloaded players are disposed and recreated on each phase transition — never accumulates.
- SfxService writes WAV to disk cache but keeps only 1 `AudioPlayer` — no in-memory audio buffers beyond playback.

---

## 6. APK Size Impact

| Item | Size | Notes |
|------|------|-------|
| **New dependencies** | ~0 KB | `crypto`, `http`, `flutter_tts`, `path_provider` all already in `pubspec.yaml` |
| **New Dart code** | ~1500 lines | 6 new/modified files (audio_engine, gemini_voice_service, sfx_service, cached_workout_info, workout_fingerprint, audio_settings_page) |
| **Compiled Dart** | ~150–200 KB | Estimated AOT compilation overhead |
| **SfxService WAV generation** | ~5 KB | WAV header logic compiled into app |
| **Total estimated APK increase** | **~200–300 KB** | Marginal — dominated by Dart AOT, no new native libraries |

**Dependency analysis:**
- `crypto: ^3.0.3` — pure Dart, no native code
- `http: ^1.2.2` — pure Dart HTTP client
- `flutter_tts: ^4.2.3` — platform-specific but already bundled (local path in pubspec)
- `path_provider: ^2.1.5` — thin platform wrapper, already bundled

---

## 7. Remaining Technical Debt

| Issue | Severity | Location | Description |
|-------|----------|----------|-------------|
| Dead volume slider | Low | `workout_timer_page.dart` | Voice volume slider UI exists but volume value is never passed to GeminiVoiceService or flutter_tts. Volume is hardcoded at 1.0. |
| Legacy workout naming | Low | `gemini_voice_service.dart:371` | Manifests without a `name` field fall back to `"Unnamed Workout"` — visible in AudioSettingsPage cache list. |
| No preloading on first run | Medium | `audio_engine.dart:97–106` | `preloadWorkout()` only preloads if `cacheExists()` is true. First-time users get no preloaded clips; all playback falls through to Gemini API or device TTS. |
| Rebuild re-generates all clips | Low | `audio_engine.dart:288–301` | `rebuildCache()` deletes entire cache and regenerates from scratch — no incremental update for changed exercises only. |

---

*Report generated from source analysis of `lib/services/audio_engine.dart`, `lib/services/gemini_voice_service.dart`, `lib/services/sfx_service.dart`, `lib/models/cached_workout_info.dart`, `lib/models/workout_fingerprint.dart`, and `lib/pages/audio_settings_page.dart`.*
