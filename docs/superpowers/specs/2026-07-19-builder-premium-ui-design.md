# Builder Player Premium UI Redesign

**Date:** 2026-07-19
**Scope:** Builder workout player page only (`workout_builder_player_page.dart`)

## Goal

Overhaul the builder player UI to be modern, glassmorphic, and media-focused. The exercise GIF/MP4 becomes the dominant visual element (55-65% of screen). Controls are simplified to one primary + two secondary buttons. Info is merged into a clean two-column card. All existing logic is preserved.

## Current State

The builder player has:
- `_ExerciseHeroCard` (280px fixed height, GIF with dark scrim + timer text)
- `_BuilderActionControls` (4 buttons: Start/Pause, Skip, Reset, Music Toggle in 2x2 grid)
- `NextPhaseCard` (separate card)
- Exercise name + next info (text below controls)
- `ProgressHeader` (separate card with progress bar + elapsed/total)
- `WorkoutTimeline` (full timeline)
- `GlowBlob` decorations (decorative, can be removed for cleaner look)

## Target Layout

```
┌──────────────────────────────────┐
│ [←] Workout Name        🔊 Music │  ← Header
├──────────────────────────────────┤
│                                  │
│       Exercise GIF / MP4         │  ← Hero: 55-65% of screen
│       (blurred edges, 24px radius)│
│                                  │
│          ● WORK                  │  ← Phase badge
│          00:40                   │  ← Timer (progress ring around it)
│                                  │
├──────────────────────────────────┤
│ ████████████████░░░░░░ 40%       │  ← Linear progress bar
│                                  │
│ Exercise: Burpees                │  ← Exercise name (20px, w800)
│                                  │
│ ──────────────────────────────── │  ← Divider
│                                  │
│ ┌──────────────┬──────────────┐  │
│ │ 🔥 Next      │ ⏱ Remaining │  │  ← Two-column info card
│ │ Rest (20s)   │ 40 seconds   │  │     (glassmorphism)
│ └──────────────┴──────────────┘  │
│                                  │
│           ▶ Start                │  ← Primary button (full width)
│     Skip              Reset      │  ← Secondary buttons (flanking)
│                                  │
│       Workout Timeline           │  ← Timeline (collapsed, optional)
└──────────────────────────────────┘
```

## Hero Area

### Height Calculation
```dart
final heroHeight = MediaQuery.of(context).size.height * 0.6;
```

### States

1. **Work phase WITH GIF/image:**
   - `Image.file(File(mediaPath))` fills the hero, `BoxFit.cover`
   - `ClipRRect` with `borderRadius: 24px` for rounded corners
   - Gradient mask at top/bottom for smooth blending
   - Timer overlay centered with glassmorphism backdrop

2. **Work phase WITHOUT GIF:**
   - Gradient background matching phase palette
   - Large exercise icon (`Icons.fitness_center_rounded`, 80px, white 0.15)
   - Same timer overlay

3. **Rest phase:**
   - Gradient background (rest palette: navy/teal)
   - Rest icon (`Icons.self_improvement_rounded`, 80px, white 0.15)
   - Same timer overlay

### Timer Overlay (glassmorphism)

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(24),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Phase badge pill
          // Progress ring + timer text
        ],
      ),
    ),
  ),
)
```

### Progress Ring

A thin circular arc around the timer that depletes as time runs out.

```dart
SizedBox(
  width: 160,
  height: 160,
  child: Stack(
    fit: StackFit.expand,
    children: [
      // Background ring (faint)
      CircularProgressIndicator(
        value: 1.0,
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation(Colors.white.withValues(alpha: 0.1)),
      ),
      // Depleting arc
      CircularProgressIndicator(
        value: _remainingSeconds / _currentPhase.durationSeconds,
        strokeWidth: 3,
        valueColor: AlwaysStoppedAnimation(phaseAccentColor),
        strokeCap: StrokeCap.round,
      ),
      // Timer text centered
      Center(
        child: Text(
          _formatTime(_remainingSeconds),
          style: TextStyle(
            color: Colors.white,
            fontSize: 56,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
          ),
        ),
      ),
    ],
  ),
)
```

### Phase Badge (inside timer overlay)

```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    color: phaseAccentColor.withValues(alpha: 0.2),
    borderRadius: BorderRadius.circular(999),
    border: Border.all(color: phaseAccentColor.withValues(alpha: 0.4)),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: phaseAccentColor)),
      SizedBox(width: 6),
      Text(isRest ? 'REST' : 'WORK', style: TextStyle(color: phaseAccentColor, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
    ],
  ),
)
```

## Info Section

### Linear Progress Bar

```dart
ClipRRect(
  borderRadius: BorderRadius.circular(99),
  child: LinearProgressIndicator(
    value: _totalProgress,
    minHeight: 8,
    valueColor: AlwaysStoppedAnimation(phaseAccentColor),
    backgroundColor: Colors.white.withValues(alpha: 0.1),
  ),
)
```

### Exercise Name

```dart
Text(
  'Exercise: ${current.label}',
  style: TextStyle(
    color: Colors.white,
    fontSize: 20,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.2,
  ),
)
```

### Two-Column Info Card

Glassmorphism container with two columns:

```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))],
  ),
  child: Row(
    children: [
      Expanded(child: _InfoColumn(icon: Icons.local_fire_department_rounded, label: 'Next', value: '${nextPhase.label} (${nextPhase.durationSeconds}s)', accent: Color(0xFFFF8A1E))),
      Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.1)),
      Expanded(child: _InfoColumn(icon: Icons.timer_rounded, label: 'Remaining', value: '${_remainingSeconds} seconds', accent: Color(0xFF60A5FA))),
    ],
  ),
)
```

## Controls

### Primary Button (Start/Pause)

```dart
SizedBox(
  width: double.infinity,
  height: 56,
  child: Container(
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: [palette[0], palette[1]]),
      borderRadius: BorderRadius.circular(16),
      boxShadow: [BoxShadow(color: palette.first.withValues(alpha: 0.4), blurRadius: 16, offset: Offset(0, 6))],
    ),
    child: FilledButton.icon(
      onPressed: _isRunning ? _pause : _start,
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        shadowColor: Colors.transparent,
        textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
      ),
      icon: Icon(_isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded),
      label: Text(_isRunning ? 'Pause' : _isComplete ? 'Restart' : 'Start'),
    ),
  ),
)
```

### Secondary Buttons (Skip, Reset)

```dart
Row(
  children: [
    Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _skip,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: Icon(Icons.skip_next_rounded, size: 18),
          label: Text('Skip'),
        ),
      ),
    ),
    SizedBox(width: 12),
    Expanded(
      child: SizedBox(
        height: 48,
        child: OutlinedButton.icon(
          onPressed: _stopAndReset,
          style: OutlinedButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            foregroundColor: Colors.white,
            backgroundColor: Colors.white.withValues(alpha: 0.06),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          icon: Icon(Icons.replay_rounded, size: 18),
          label: Text('Reset'),
        ),
      ),
    ),
  ],
)
```

## Changes to Existing Code

### Remove
- `_BuilderHeroSessionCard` class (replaced by new hero)
- `_ExerciseMediaPreview` class (content moved into hero)
- `_RestPhaseMessageCard` class (rest state handled by hero)
- `_BuilderActionControls` class (replaced by new controls)
- `GlowBlob` usage (removed for cleaner look)

### Modify
- `build()` method: Complete rewrite of widget tree
- `_ExerciseHeroCard`: Complete rewrite with progress ring, glassmorphism, responsive height
- Add `_formatTime(int seconds)` helper for MM:SS display
- Add `_InfoColumn` widget for two-column card

### Keep unchanged
- All timer/cue/phase logic
- `_start()`, `_pause()`, `_stopAndReset()`, `_skip()`
- CueService integration
- Music service integration
- Resume logic
- `_buildTimeline()`, `_phasePalette`, `_totalSeconds`, `_elapsedSeconds`, `_totalProgress`
- `WorkoutTimeline` widget (kept at bottom)

## Styling Constants

| Property | Value |
|----------|-------|
| Hero height | `MediaQuery.of(context).size.height * 0.6` |
| Card border radius | 20-24px |
| Button border radius | 14-16px |
| Primary button height | 56px |
| Secondary button height | 48px |
| Progress ring stroke width | 3px |
| Progress bar height | 8px |
| Glassmorphism background | `Colors.white.withValues(alpha: 0.06)` |
| Glassmorphism border | `Border.all(color: Colors.white.withValues(alpha: 0.12))` |
| Glassmorphism blur | `ImageFilter.blur(sigmaX: 10, sigmaY: 10)` |
| Shadow | `BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4))` |
| Timer font size | 56px, w900 |
| Exercise name font size | 20px, w800 |
| Info card font size | 14px, w600-w700 |

## Verification

1. `flutter analyze` — no issues
2. Hero fills 55-65% of screen height
3. Progress ring depletes as time runs out
4. Glassmorphism effect visible on timer overlay and info card
5. One primary Start button + two secondary buttons
6. Two-column info card shows Next and Remaining
7. All existing functionality works (start, pause, reset, skip, cues, music)
8. Community-downloaded workouts play correctly
