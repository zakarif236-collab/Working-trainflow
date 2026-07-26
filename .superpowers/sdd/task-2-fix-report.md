# Task 2 Fix Report: Remove dead `_pulseController` animation code

## File
`lib/pages/workout_builder_player_page.dart`

## What was removed

| Location | Removed code |
|----------|-------------|
| Line 38–39 | `with SingleTickerProviderStateMixin` from class declaration |
| Line 42 | `late final AnimationController _pulseController;` field |
| Lines 62–67 | `_pulseController = AnimationController(...)` initialization in `initState()` |
| Line 114 | `_pulseController.dispose()` in `dispose()` |
| Line 362 | `_pulseController.repeat(reverse: true)` in `_start()` |
| Lines 389–390 | `_pulseController.stop(); _pulseController.value = 1;` in `_pause()` |
| Lines 396–397 | `_pulseController.stop(); _pulseController.value = 1;` in `_stopAndReset()` |

## Why

`_pulseController` drove a `ScaleTransition` on the old `_BuilderHeroSessionCard`. After that card was replaced with `_ExerciseHeroCard`, no widget consumed the animation, leaving a controller that ran invisibly during every workout session.

## Verification

```
flutter analyze lib/pages/workout_builder_player_page.dart
# → No issues found!
```
