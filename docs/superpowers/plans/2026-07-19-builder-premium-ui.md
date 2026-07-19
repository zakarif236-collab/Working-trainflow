# Builder Player Premium UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Overhaul the builder player UI with glassmorphism, a large GIF hero with progress ring, simplified controls, and a two-column info card.

**Architecture:** Single-file rewrite of `workout_builder_player_page.dart`. New private widgets replace old ones. All timer/cue/phase logic preserved unchanged.

**Tech Stack:** Flutter, Dart, existing shared widgets from `workout_player_widgets.dart`

## Global Constraints

- Builder player page only — timer page unchanged
- `flutter analyze` must pass with no issues after each task
- Preserve ALL existing timer/cue/phase logic — only change visual layout
- Community-downloaded workouts use the same builder player (no separate changes)
- Glassmorphism: `color: Colors.white.withValues(alpha: 0.06)`, `border: Border.all(color: Colors.white.withValues(alpha: 0.12))`, `BackdropFilter(filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10))`
- Card border radius: 20-24px
- Primary button: full width, 56px height, gradient, 16px radius
- Secondary buttons: equal width, 48px height, translucent, 14px radius

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/pages/workout_builder_player_page.dart` | Modify | Complete UI rewrite (hero, controls, info, build method) |

No new files — all widgets are private to this page.

---

### Task 1: Rewrite `_ExerciseHeroCard` with progress ring and glassmorphism

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart` (rewrite `_ExerciseHeroCard` class)

**Interfaces:**
- Consumes: `mediaPath` (String), `remainingSeconds` (int), `totalSeconds` (int), `phaseLabel` (String), `isRestPhase` (bool), `palette` (List<Color>), `phaseBadge` (Widget)
- Produces: `_ExerciseHeroCard` widget used by `build()` method

- [ ] **Step 1: Replace `_ExerciseHeroCard` with new implementation**

Delete the existing `_ExerciseHeroCard` class (lines ~728-841) and replace with:

```dart
class _ExerciseHeroCard extends StatelessWidget {
  const _ExerciseHeroCard({
    required this.mediaPath,
    required this.remainingSeconds,
    required this.totalSeconds,
    required this.phaseLabel,
    required this.isRestPhase,
    required this.palette,
    required this.phaseBadge,
  });

  final String mediaPath;
  final int remainingSeconds;
  final int totalSeconds;
  final String phaseLabel;
  final bool isRestPhase;
  final List<Color> palette;
  final Widget phaseBadge;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final heroHeight = screenHeight * 0.6;
    final hasMedia = !isRestPhase && mediaPath.trim().isNotEmpty;
    final progress = totalSeconds > 0 ? remainingSeconds / totalSeconds : 0.0;
    final accentColor = isRestPhase ? const Color(0xFF60A5FA) : palette.first;

    return SizedBox(
      height: heroHeight,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasMedia)
              Image.file(
                File(mediaPath.trim()),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _buildGradientBackground(),
              )
            else
              _buildGradientBackground(),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45, Colors.black87],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: phaseBadge,
            ),
            Center(
              child: _TimerOverlay(
                remainingSeconds: remainingSeconds,
                progress: progress,
                accentColor: accentColor,
                phaseLabel: phaseLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette[0], const Color(0xFF0D121C), palette[1]],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          isRestPhase ? Icons.self_improvement_rounded : Icons.fitness_center_rounded,
          color: Colors.white.withValues(alpha: 0.12),
          size: 80,
        ),
      ),
    );
  }
}

class _TimerOverlay extends StatelessWidget {
  const _TimerOverlay({
    required this.remainingSeconds,
    required this.progress,
    required this.accentColor,
    required this.phaseLabel,
  });

  final int remainingSeconds;
  final double progress;
  final Color accentColor;
  final String phaseLabel;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: accentColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      phaseLabel.toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CircularProgressIndicator(
                      value: 1.0,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(
                        Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation(accentColor),
                      strokeCap: StrokeCap.round,
                    ),
                    Center(
                      child: Text(
                        _formatTime(remainingSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 56,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.black87, blurRadius: 12),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found (the widget may show as unused until Task 3 integrates it)

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat(builder): rewrite hero card with progress ring and glassmorphism"
```

---

### Task 2: Add `_InfoCard` and `_ControlBar` widgets

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart` (add new classes)

**Interfaces:**
- Consumes: Nothing from earlier tasks
- Produces: `_InfoCard` and `_ControlBar` widgets used by `build()` method

- [ ] **Step 1: Add `_InfoColumn` widget**

Add at the bottom of the file:

```dart
class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.icon,
    required this.label,
    required this.value,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Add `_InfoCard` widget**

```dart
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.nextLabel,
    required this.nextDuration,
    required this.remainingSeconds,
  });

  final String nextLabel;
  final int nextDuration;
  final int remainingSeconds;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoColumn(
              icon: Icons.local_fire_department_rounded,
              label: 'Next',
              value: '$nextLabel (${nextDuration}s)',
              accent: const Color(0xFFFF8A1E),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          Expanded(
            child: _InfoColumn(
              icon: Icons.timer_rounded,
              label: 'Remaining',
              value: '$remainingSeconds seconds',
              accent: const Color(0xFF60A5FA),
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 3: Add `_ControlBar` widget**

```dart
class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.running,
    required this.complete,
    required this.palette,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
  });

  final bool running;
  final bool complete;
  final List<Color> palette;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [palette[0], palette[1]]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: palette.first.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: onStartPause,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                textStyle: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: Icon(running ? Icons.pause_rounded : Icons.play_arrow_rounded),
              label: Text(running ? 'Pause' : complete ? 'Restart' : 'Start'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onSkip,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('Skip'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                    textStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('Reset'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat(builder): add _InfoCard and _ControlBar widgets"
```

---

### Task 3: Rewrite `build()` method and remove old widgets

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart` (rewrite `build()`, delete old classes)

**Interfaces:**
- Consumes: `_ExerciseHeroCard` (Task 1), `_InfoCard` (Task 2), `_ControlBar` (Task 2)
- Produces: Updated `build()` method using new widgets

- [ ] **Step 1: Rewrite the `build()` method**

Replace the entire `build()` method body (the main path, not the null-routine guard) with:

```dart
    final routine = _routine;
    if (routine == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF141B2D), Color(0xFF0A1020), Color(0xFF1A2439)],
            ),
          ),
          child: const Center(
            child: Text(
              'Unable to load workout.',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final current = _currentPhase;
    final palette = _phasePalette;
    final nextPhase = _nextPhase;
    final accentColor = current.type == _BuilderPhaseType.rest
        ? const Color(0xFF60A5FA)
        : palette.first;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [palette[0], const Color(0xFF0D121C), palette[1]],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (Navigator.of(context).canPop())
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            final navigator = Navigator.of(context);
                            if (navigator.canPop()) {
                              navigator.pop();
                            }
                          },
                          icon: const Icon(
                            Icons.arrow_back_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (Navigator.of(context).canPop())
                      const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _phaseHeaderSubtitle(current),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 12,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _ExerciseHeroCard(
                      mediaPath: current.type == _BuilderPhaseType.work
                          ? current.exercise.mediaPath
                          : '',
                      remainingSeconds: _remainingSeconds,
                      totalSeconds: current.durationSeconds,
                      phaseLabel: current.label,
                      isRestPhase: current.type == _BuilderPhaseType.rest,
                      palette: palette,
                      phaseBadge: PhaseBadge(
                        icon: current.type == _BuilderPhaseType.rest
                            ? Icons.pause_rounded
                            : Icons.fitness_center_rounded,
                        label: current.type == _BuilderPhaseType.rest
                            ? 'REST'
                            : 'WORK',
                        accent: accentColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: _totalProgress,
                        minHeight: 8,
                        valueColor: AlwaysStoppedAnimation(accentColor),
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Exercise: ${current.label}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    const SizedBox(height: 16),
                    if (!_isComplete)
                      _InfoCard(
                        nextLabel: nextPhase.label,
                        nextDuration: nextPhase.durationSeconds,
                        remainingSeconds: _remainingSeconds,
                      ),
                    const SizedBox(height: 20),
                    _ControlBar(
                      running: _isRunning,
                      complete: _isComplete,
                      palette: palette,
                      onStartPause: _isRunning ? _pause : (_isComplete ? _stopAndReset : _start),
                      onReset: _stopAndReset,
                      onSkip: _skip,
                    ),
                    const SizedBox(height: 24),
                    WorkoutTimeline(
                      timeline: _timeline.map(_toWorkoutPhase).toList(),
                      currentIndex: _phaseIndex,
                      currentRemainingSeconds: _remainingSeconds,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
```

- [ ] **Step 2: Delete old widget classes**

Delete these classes from the file:
- `_BuilderActionControls` (lines ~668-726)
- Any remaining old widgets that are no longer referenced

- [ ] **Step 3: Remove unused import if applicable**

Check if `circular_countdown.dart` import is still needed. If `_ExerciseHeroCard` no longer uses `CircularCountdown` as a fallback (the new version always shows the hero), remove the import.

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 5: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat(builder): rewrite build method with premium UI layout"
```

---

### Task 4: Final verification

**Files:**
- Verify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: Nothing
- Produces: Confirmed working state

- [ ] **Step 1: Run full project analysis**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Verify key behaviors**

Check that:
1. Hero fills 55-65% of screen height
2. Progress ring depletes as time runs out
3. Glassmorphism effect visible on timer overlay and info card
4. One primary Start button + two secondary buttons (Skip, Reset)
5. Two-column info card shows Next and Remaining
6. Exercise name displays below progress bar
7. All existing functionality works (start, pause, reset, skip, cues, music)
8. Community-downloaded workouts play correctly
9. Timer page is unchanged

- [ ] **Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: finalize builder player premium UI"
```
