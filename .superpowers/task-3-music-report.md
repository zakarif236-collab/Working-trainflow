# Task 3: Fix AudioEngine ducking in WorkoutTimerPage

**Status:** Complete

## Change
Added `music: _musicService` parameter to the `AudioEngine` constructor in `lib/pages/workout_timer_page.dart:118`.

## Verification
`flutter analyze lib/pages/workout_timer_page.dart` — No issues found.

## Commit
```
fix: pass MusicService to AudioEngine for ducking in WorkoutTimerPage
```
