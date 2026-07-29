# Task 5: Replace music UI in WorkoutTimerLayout with MusicControls

**Status:** Complete

## Summary

Replaced the old music params (`onMusicToggle`, `isMusicPlaying`, `selectedSongTitle`, `loadingSongs`, `onMusicPickerTap`, `songName`) and the `_MusicChip` header widget with a single `musicControls` param (Widget?) on `WorkoutTimerLayout`.

## Changes

### `lib/widgets/workout_timer_layout.dart`
- Removed 6 music-related constructor params and their fields
- Added `this.musicControls` (Widget?) param and field
- Removed `_MusicChip` widget from header Row
- Removed `_MusicChip` class definition (44 lines deleted)
- Removed music params from `ActionControls` call (replaced with no-ops since `MusicControls` handles it)
- Added `musicControls` widget rendered below `ActionControls`

### `lib/pages/workout_timer_page.dart`
- Added `import 'package:my_app/widgets/music_controls.dart';`
- Replaced 6 old music params with `musicControls: MusicControls(musicService: _musicService, onOpenPicker: _openMusicPicker)`
- Removed unused `_loadingSongs` field and its usages in `_openMusicPicker()`
- Removed unused `_toggleMusic()` method

## Verification

`flutter analyze lib/pages/workout_timer_page.dart lib/widgets/workout_timer_layout.dart` — **No issues found**

## Commit

`9225257` — `feat: replace music UI with MusicControls in WorkoutTimerLayout`
