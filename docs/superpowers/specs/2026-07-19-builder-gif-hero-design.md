# Builder Player GIF Hero Layout

**Date:** 2026-07-19
**Scope:** Builder workout player page only (`workout_builder_player_page.dart`)

## Goal

Replace the current circular countdown hero with an exercise GIF/image hero. The GIF fills a fixed-height area at the top of the scrollable content, with the timer overlaid on top using a dark scrim for readability. When no GIF is available, fall back to the existing circular countdown widget.

## Current State

The builder player currently has:
- `_BuilderHeroSessionCard` containing `CircularCountdown` (square, centered, 360px max width)
- `_ExerciseMediaPreview` below the controls (220px tall image, `BoxFit.cover`)
- `_BuilderActionControls` (Start/Pause, Skip, Reset, Music Toggle)
- `NextPhaseCard`, `ProgressHeader`, `WorkoutTimeline`

## Target Layout

```
┌─────────────────────────────────┐
│ [←]  Routine Name               │  ← Header (unchanged)
│      Phase subtitle             │
├─────────────────────────────────┤
│ ┌─────────────────────────────┐ │
│ │  Exercise GIF / Rest Icon   │ │  ← Hero: 280px fixed height
│ │                             │ │
│ │       ┌─────────┐           │ │  ← Timer overlay (dark scrim)
│ │       │  0:40   │           │ │
│ │       └─────────┘           │ │
│ └─────────────────────────────┘ │
│                                 │
│  Burpees                        │  ← Exercise name (bold, 18px)
│  Next: Rest (20s)               │  ← Next phase info (muted, 14px)
│                                 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │  ← Progress bar
│                                 │
│  [Start/Pause]  [Skip]          │  ← Controls (4 buttons, unchanged)
│  [Reset]  [Music Toggle]        │
│                                 │
│  Workout Timeline               │  ← Timeline (unchanged)
└─────────────────────────────────┘
```

## Hero States

### State 1: Work phase WITH GIF/image

- Background: `Image.file(File(mediaPath))` with `BoxFit.cover`, filling the 280px hero
- Dark scrim: `Container` with `LinearGradient` from `Colors.transparent` (top) to `Colors.black54` (bottom), covering the full hero
- Timer overlay: Centered `Column` with:
  - Seconds display: `Text('${_remainingSeconds}s', ...)` — white, bold, 48px, with text shadow
  - Phase label: `Text(exerciseName, ...)` — white70, 14px, maxLines 1, ellipsis
- Phase badge: Top-right corner, small "WORK" pill using `PhaseBadge` from shared widgets

### State 2: Work phase WITHOUT GIF/image

- Falls back to current `_BuilderHeroSessionCard` with `CircularCountdown` widget
- No change from current behavior for this state

### State 3: Rest phase

- Background: Same animated gradient as the page background (rest colors)
- Centered rest icon: `Icons.self_improvement_rounded` (or similar), white with 0.3 opacity, 64px
- Dark scrim: Same gradient as State 1
- Timer overlay: Same as State 1 but label shows "Rest"
- Phase badge: Top-right corner, "REST" pill

## New Widget: `_ExerciseHeroCard`

Location: Inside `workout_builder_player_page.dart` (private to this page)

```dart
class _ExerciseHeroCard extends StatelessWidget {
  const _ExerciseHeroCard({
    required this.mediaPath,
    required this.remainingSeconds,
    required this.phaseLabel,
    required this.isRestPhase,
    required this.palette,
    required this.phaseBadge,
  });

  final String mediaPath;
  final int remainingSeconds;
  final String phaseLabel;
  final bool isRestPhase;
  final List<Color> palette;
  final Widget phaseBadge;
}
```

### Build logic

```
if (mediaPath is not empty AND not rest phase)
  → Stack: Image.file + dark scrim gradient + timer text + phase badge
else if (rest phase)
  → Stack: gradient background + rest icon + dark scrim gradient + timer text + phase badge
else
  → CircularCountdown widget (existing fallback)
```

### Dark scrim gradient

```dart
Container(
  decoration: const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Colors.transparent, Colors.black54],
      stops: [0.4, 1.0],
    ),
  ),
)
```

### Timer text style

```dart
Text(
  '${remainingSeconds}s',
  style: const TextStyle(
    color: Colors.white,
    fontSize: 48,
    fontWeight: FontWeight.w900,
    letterSpacing: 1.2,
    shadows: [
      Shadow(color: Colors.black87, blurRadius: 12),
    ],
  ),
)
```

## Changes to Existing Code

### Remove
- `_BuilderHeroSessionCard` class (replaced by `_ExerciseHeroCard`)
- `_ExerciseMediaPreview` class (content moved into hero)

### Modify
- `build()` method: Replace `_BuilderHeroSessionCard` + `_ExerciseMediaPreview` with `_ExerciseHeroCard`
- Exercise info section: Add exercise name and next phase info text below the hero
- `_toWorkoutPhase()`: Ensure it maps `_BuilderPhase` to `WorkoutPhase` correctly for `NextPhaseCard`

### Keep unchanged
- `_BuilderActionControls` (controls layout)
- `NextPhaseCard` (next phase display)
- `ProgressHeader` (progress bar)
- `WorkoutTimeline` (timeline)
- All timer/cue/phase logic

## Exercise Info Section

Below the hero, before controls:

```dart
Column(
  children: [
    Text(
      current.label,  // e.g. "Burpees"
      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 4),
    Text(
      'Next: ${nextPhase.label} (${nextPhase.durationSeconds}s)',
      style: TextStyle(color: Colors.white54, fontSize: 14),
    ),
  ],
)
```

## Verification

1. `flutter analyze lib/pages/workout_builder_player_page.dart` — no issues
2. Visual check: GIF hero fills the top area, timer is readable over any image
3. Fallback check: Exercises without GIF show circular countdown
4. Rest phase check: Shows rest icon + timer, no image
5. Controls check: All 4 buttons work (Start/Pause, Skip, Reset, Music Toggle)
6. Community download check: Downloaded workouts play correctly with GIF hero
