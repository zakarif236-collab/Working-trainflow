# Builder Player UI Redesign

## Goal

Redesign `WorkoutBuilderPlayerPage` to match the visual quality of `WorkoutTimerPage` — animated gradients, circular countdown, glow effects, styled controls, and a premium Nike-style aesthetic. Extract shared visual widgets so both pages use the same components.

## Scope

- Rewrite `workout_builder_player_page.dart` build method and add animations
- Extract shared visual widgets from `workout_timer_page.dart` into `lib/widgets/workout_player_widgets.dart`
- Refactor `workout_timer_page.dart` to import extracted widgets
- Add countdown beep sounds (3-2-1) with distinct final-second tone to `CueService`
- Ensure exercise GIF/image attachment box is prominently placed and well-synchronized in the new layout

## Current State

**Builder Player (`workout_builder_page.dart` lines 422-617):**
- `Scaffold` with `AppBar` (routine name)
- Static gradient `DecoratedBox`
- `ListView` with: info card (text name, meta chips, linear progress bars, plain countdown number), media preview, 3 equal buttons, vertical timeline list

**Timer Page (`workout_timer_page.dart`):**
- No `AppBar` — custom header with back button
- `AnimatedContainer` with phase-colored gradient
- `_GlowBlob` ambient light effects
- `_HeroSessionCard` with `CircularCountdown` (pulsing), status badge, phase badges
- `_ActionControls` with primary gradient button + outlined secondaries
- `_NextPhaseCard`, `_ExerciseMediaPanel`, `_ProgressHeader`, `WorkoutTimeline`
- `AnimationController` for pulse effect

## Design

### 1. Page Structure

Replace the builder player's `build()` method:

```
Scaffold (no AppBar)
  Stack [
    AnimatedContainer — phase-based gradient background
    GlowBlob (top-left, palette.first)
    GlowBlob (bottom-right, palette.last)
    SafeArea
      Column [
        Header row — back button + routine name + subtitle
        Expanded(ListView [
          SizedBox(height: 8)
          HeroSessionCard (circular countdown + status badge + phase badges)
          SizedBox(height: 12)
          ActionControls (Start/Pause + Skip / Reset)
          SizedBox(height: 12)
          NextPhaseCard
          SizedBox(height: 12)
          ExerciseMediaPreview
          SizedBox(height: 12)
          ProgressHeader
          SizedBox(height: 12)
          WorkoutTimeline
          SizedBox(height: 20)
        ])
      ]
  ]
```

### 2. Phase Color Palette

Add `_BuilderPhasePalette` to map `_BuilderPhaseType` to colors:

| Phase    | Primary         | Secondary       |
|----------|-----------------|-----------------|
| work     | `Color(0xFF8B1A2A)` | `Color(0xFFFF5A5F)` |
| rest     | `Color(0xFF0E4D6B)` | `Color(0xFF2AB7CA)` |
| complete | `Color(0xFF333333)` | `Color(0xFF666666)` |

### 3. Animations

- Add `SingleTickerProviderStateMixin` to `_WorkoutBuilderPlayerPageState`
- Add `AnimationController _pulseController` (duration 800ms, bounds 0.97-1.03)
- Wrap `CircularCountdown` in `ScaleTransition(scale: _pulseController)`
- Start/stop pulse controller based on `_isRunning`
- `AnimatedContainer` on background with 800ms `easeInOut` curve

### 4. Extracted Shared Widgets

New file: `lib/widgets/workout_player_widgets.dart`

Widgets to extract (currently private in `workout_timer_page.dart`):

| Widget | Purpose |
|--------|---------|
| `GlowBlob` | Ambient light circle (blur + opacity) |
| `PhaseStatusBadge` | Running/Ready pill with glowing dot |
| `NextPhaseCard` | "Up next" info card |
| `ProgressHeader` | Progress bar + percentage + elapsed/total |
| `PlayerActionControls` | Two-row button layout (primary + secondary) |
| `PlayerControlButton` | Individual styled button (gradient primary or outlined secondary) |
| `PhaseBadge` | Small labeled icon pill for phase/duration |

### 5. Timer Page Refactoring

Replace private widget usages in `workout_timer_page.dart` with imports from `workout_player_widgets.dart`:
- `_GlowBlob` → `GlowBlob`
- `_NextPhaseCard` → `NextPhaseCard`
- `_ProgressHeader` → `ProgressHeader`
- `_ActionControls` → `PlayerActionControls`
- `_ControlButton` → `PlayerControlButton`

Keep timer-page-specific widgets private: `_HeroSessionCard`, `_ConfigPanel`, `_MusicChip`, `_CustomizationToggleCard`, `_PhaseTempoPanel`, guide cards.

### 6. Builder Player State Changes

Add to `_WorkoutBuilderPlayerPageState`:
- `late final AnimationController _pulseController` — initialized in `initState`, disposed in `dispose`
- `_BuilderPhasePalette` getter based on `_currentPhase.type`
- `_nextPhase` computed property (phase after current, or current if last)

Remove:
- `AppBar` usage
- Flat card container with text countdown
- Single-row button layout

### 7. Exercise GIF/Image Attachment Box

The builder editor already supports attaching GIF/image files to exercises via `_attachMedia()` in `workout_builder_page.dart`. The `WorkoutBuilderExercise` model stores the `mediaPath`. In the player, `_ExerciseMediaPreview` displays this media.

**Changes for the new UI:**
- Keep `_ExerciseMediaPreview` widget in the builder player file (already clean)
- Position it prominently in the layout: directly below the controls, above the progress header
- During rest phases, show `_RestPhaseMessageCard` instead (existing behavior, keep as-is)
- During work phases with media: show the GIF/image full-width with rounded corners (existing behavior)
- During work phases without media: show a styled placeholder matching the new card aesthetic (update `_ExerciseMediaPreview` empty state to use the same card decoration as other cards — rounded corners, white-alpha border, glow shadow)

### 8. Countdown Beep Sounds (3-2-1)

Add audio beep feedback for the final 5 seconds of each phase, with a distinct tone for the last second.

**CueService changes (`lib/services/cue_service.dart`):**

Add two new methods:

```dart
/// Plays a short beep tone for countdown (seconds 5-2).
/// Uses a standard 880Hz sine wave, 100ms duration.
Future<void> playCountdownBeep() async { ... }

/// Plays a distinct, higher-pitched beep for the final second (1).
/// Uses a 1320Hz sine wave, 200ms duration, slightly louder.
Future<void> playCountdownFinalBeep() async { ... }
```

Implementation: Generate a simple WAV sine wave in memory using `dart:typed_data`, write to a temp file, play via the existing `_cachePlayer` (`just_audio`). No new asset files needed.

- `playCountdownBeep()`: 880Hz, 100ms, volume 0.7
- `playCountdownFinalBeep()`: 1320Hz, 200ms, volume 1.0

**Builder Player changes (`lib/pages/workout_builder_player_page.dart`):**

Update `_handleWorkoutCues()` countdown section (currently lines 198-216):

```
Current behavior (lines 200-215):
  if (_remainingSeconds > 0 && _remainingSeconds <= 5) {
    haptic feedback (lightImpact for <=3, selectionClick for 4-5)
    voice cue: speakCount(_remainingSeconds)
  }

New behavior:
  if (_remainingSeconds > 0 && _remainingSeconds <= 5) {
    haptic feedback (same as before)
    if (_remainingSeconds == 1) {
      await _cueService.playCountdownFinalBeep()  // distinct final tone
    } else {
      await _cueService.playCountdownBeep()        // standard beep
    }
    voice cue: speakCount(_remainingSeconds)       // keep existing TTS
  }
```

The beep plays alongside the existing haptic feedback and voice cues — layered audio/haptic response for the countdown.

**Timer Page changes (`lib/pages/workout_timer_page.dart`):**

Apply the same countdown beep pattern to `_handleWorkoutCues()` (around line 556). Both pages get consistent countdown audio.

## Files Modified

| File | Change |
|------|--------|
| `lib/pages/workout_builder_player_page.dart` | Full rewrite of `build()`, add animation controller, add phase palette, wire up countdown beeps |
| `lib/widgets/workout_player_widgets.dart` | New file — extracted shared visual widgets |
| `lib/pages/workout_timer_page.dart` | Replace private widget usages with imports, add countdown beeps |
| `lib/services/cue_service.dart` | Add `playCountdownBeep()` and `playCountdownFinalBeep()` methods |

## What Stays the Same

- All business logic (timer, phases, cues, resume, skip, reset) — untouched
- `_BuilderPhase`, `_BuilderPhaseType`, `_ExerciseMediaPreview`, `_RestPhaseMessageCard` — stay in builder player file
- `_WorkoutDraftExercise` and builder page — untouched
- `CircularCountdown` widget — reused as-is from `lib/widgets/circular_countdown.dart`
- `WorkoutTimeline` widget — reused as-is from `lib/widgets/workout_timeline.dart`

## Verification

1. `flutter analyze` — no issues
2. Builder player: start a workout, verify animated gradient changes with phases, circular countdown pulses, buttons styled correctly, timeline renders
3. Timer page: verify it still works identically after refactoring imports
4. Builder player: skip, reset, pause, resume — all functional
5. Builder player: exercise GIF/image preview shows during work phases, rest message shows during rest phases
6. Builder player: resume from saved session still works
7. Builder player: countdown 5-4-3-2-1 produces beep sounds, with a distinct higher tone on second 1
8. Timer page: countdown beep sounds work identically
