# Task 1 Fix Report

## Summary
Fixed two code review issues in `lib/pages/workout_builder_player_page.dart`.

## Issue 1: Glassmorphism alpha values wrong

**File:** `lib/pages/workout_builder_player_page.dart` — `_TimerOverlay` widget (lines 847–849)

| Property | Before | After |
|----------|--------|-------|
| Container fill | `Colors.white.withValues(alpha: 0.08)` | `Colors.white.withValues(alpha: 0.06)` |
| Border stroke | `Colors.white.withValues(alpha: 0.15)` | `Colors.white.withValues(alpha: 0.12)` |

## Issue 2: Background icon behavior changed unexpectedly

**File:** `lib/pages/workout_builder_player_page.dart` — `_ExerciseHeroCard._buildGradientBackground()` (lines 816–818)

| Property | Before | After |
|----------|--------|-------|
| Icon | `isRestPhase ? Icons.self_improvement_rounded : Icons.fitness_center_rounded` | `Icons.self_improvement_rounded` |
| Opacity | `0.12` | `0.2` |
| Size | `80` | `64` |

## Verification
- `flutter analyze lib/pages/workout_builder_player_page.dart` — **No issues found**

## Commit
`fix(builder): correct glassmorphism alpha values and background icon` (7b7f4e4)
