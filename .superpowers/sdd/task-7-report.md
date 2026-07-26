# Task 7 Report: Audio Performance Audit

**Status: DONE_WITH_CONCERNS**

## Per-File Audit Results

### 1. `lib/services/audio_engine.dart` ✅ CLEAN

- **AudioPlayers found**: None directly owned. Holds references to `GeminiVoiceService` and `SfxService` which manage their own players.
- **Lifecycle**: Properly calls `_voice.dispose()` and `_sfx.dispose()` in `dispose()`. `stop()` clears queue, stops voice, stops TTS, unducks music.
- **No duplicate players**: `_AudioQueue` processes tasks sequentially. No concurrent play conflicts.
- **Memory leaks**: None. Queue cleared and services disposed.
- **Dead code**: `_voiceVolume` confirmed removed (not present anywhere via grep).
- **Issues**: None.

### 2. `lib/services/gemini_voice_service.dart` ⚠️ FIXED

- **AudioPlayers found**:
  - `_player` (line 13): Created in `initialize()`, disposed in `dispose()`. ✅
  - `_clipPlayers` (line 18): Map of preloaded AudioPlayers. Created in `preloadClips()`, disposed in `preloadClips()` (at start), `disposePreloadedClips()`, and `dispose()`. ✅
- **No duplicate players**: `preloadClips()` disposes all existing players before creating new ones. ✅
- **Memory leaks**: **FIXED** — In `preloadClips()`, if `AudioPlayer()` succeeds but `setFilePath()` throws, the player was created but never added to `_clipPlayers` and never disposed (native platform resources leaked). Added disposal in the catch block.
- **Dead code**: None.
- **Issues**: Memory leak fixed.

### 3. `lib/services/sfx_service.dart` ✅ CLEAN

- **AudioPlayers found**: `_player` (line 9): Single player created in `initialize()`, disposed in `dispose()`. ✅
- **No duplicate players**: Single shared player for all sound effects. ✅
- **Memory leaks**: None. Player properly disposed.
- **Dead code**: None.
- **Issues**: None. Clean implementation.

### 4. `lib/services/music_service.dart` ✅ CLEAN

- **AudioPlayers found**: `_player` (line 12): Created in constructor, disposed in `dispose()`. ✅
- **No duplicate players**: Single player. ✅
- **Memory leaks**: None.
- **Dead code**: None.
- **Issues**: None.

### 5. `lib/pages/workout_timer_page.dart` ⚠️ CONCERN

- **AudioEngine lifecycle**: Created in `initState()` (line 112), disposed in `dispose()` (line 138). ✅
- **MusicService lifecycle**: Created in `initState()` (line 110), disposed in `dispose()` (line 139). ✅
- **Memory leaks**: None. All controllers, timers, video controllers, and audio services properly disposed.
- **Orphaned timers**: `_settingsPersistDebounce` properly cancelled in `dispose()`. ✅
- **Dead code**: **`_voiceCueVolume`** (line 87) is tracked in state, persisted to `AppSettings`, and displayed in the `_ConfigPanel` voice volume slider (line 2244), but the value is **never applied to any audio service**. The slider has no effect on playback volume. This is orphaned state/dead UI.
- **Issues**: Voice volume slider is non-functional dead code. Recommend either wiring it to the audio engine or removing the UI control.

### 6. `lib/pages/workout_builder_player_page.dart` ✅ CLEAN

- **AudioEngine lifecycle**: Created in `initState()` (line 65), disposed in `dispose()` (line 121). ✅
- **Memory leaks**: None. `_ticker` cancelled, audio engine disposed.
- **Dead code**: None.
- **Issues**: None.

## Fixes Applied

1. **`lib/services/gemini_voice_service.dart`** — Fixed AudioPlayer leak in `preloadClips()` where a player could be created but never disposed if `setFilePath()` threw an exception. Added proper disposal in the catch block.

## Dead Code Verification

- ✅ `_voiceVolume` confirmed removed from `AudioEngine` (grep found zero matches).
- ✅ Voice volume slider confirmed removed from `AudioSettingsPage`.
- ⚠️ Voice volume slider still exists in `workout_timer_page.dart` `_ConfigPanel` but value is never applied (orphaned UI).
