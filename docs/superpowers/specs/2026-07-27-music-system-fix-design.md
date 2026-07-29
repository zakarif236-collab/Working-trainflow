# Music System Fix — Design Spec

## Goal
Unified music controls across all timer screens with play/pause/skip/stop, proper ducking, and reactive UI.

## Architecture

### New: MusicControls widget (`lib/widgets/music_controls.dart`)
Single reusable widget that handles the full music lifecycle:
- **Idle state**: Music icon → opens picker
- **Playing state**: Animated row with play/pause, skip next, stop + track name
- **Stopped state**: Returns to Music icon

### MusicService changes (`lib/services/music_service.dart`)
- Add `ValueNotifier<bool> playingNotifier` for reactive UI
- Add `ValueNotifier<SongModel?> songNotifier` for reactive UI
- Update notifiers in `playSong()`, `stop()`, `togglePlayPause()`

### AudioEngine fix
- WorkoutTimerPage must pass `music: _musicService` to AudioEngine constructor

### HomeTimerLayout fix
- Accept music params, wire to MusicControls

### Shared music logic
- Extract `_openMusicPicker()` into a mixin `MusicPickerMixin` used by both timer pages

## Components

| Component | File | Purpose |
|-----------|------|---------|
| MusicControls | `lib/widgets/music_controls.dart` | Unified music UI widget |
| MusicPickerMixin | `lib/widgets/music_picker_mixin.dart` | Shared picker logic |
| MusicService | `lib/services/music_service.dart` | Add reactive notifiers |
| WorkoutTimerPage | `lib/pages/workout_timer_page.dart` | Wire music to AudioEngine + HomeTimerLayout |
| WorkoutTimerLayout | `lib/widgets/workout_timer_layout.dart` | Accept MusicControls |
| HomeTimerLayout | `lib/widgets/home_timer_layout.dart` | Accept music params |
| WorkoutBuilderPlayerPage | `lib/pages/workout_builder_player_page.dart` | Use MusicControls + mixin |

## UI Behavior

### MusicControls states
```
[IDLE] → tap → open picker → song starts → [PLAYING]
[PLAYING] → tap play/pause → toggle playback
[PLAYING] → tap skip → next song
[PLAYING] → tap stop → music.stop() → [IDLE]
```

### Animation
AnimatedContainer between idle/playing states. No flicker.

### Ducking
AudioEngine ducks music before voice/beeps, unducks after. Already works in builder player, needs fix in workout timer.

## Design Tokens
- Accent: `Color(0xFFFF8A1E)`
- Background: `Colors.white.withValues(alpha: 0.06)`
- Border: `Colors.white.withValues(alpha: 0.12)`
