# Builder Player GIF Hero Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the builder player's circular countdown hero with an exercise GIF/image hero, with timer overlaid via dark scrim.

**Architecture:** Single-page UI rewrite of `workout_builder_player_page.dart`. New `_ExerciseHeroCard` widget replaces `_BuilderHeroSessionCard` and `_ExerciseMediaPreview`. Three hero states: GIF+timer, rest+icon+timer, fallback to circular countdown.

**Tech Stack:** Flutter, Dart, existing shared widgets from `workout_player_widgets.dart`, `circular_countdown.dart`

## Global Constraints

- Builder player page only — timer page unchanged
- Community-downloaded workouts use the same builder player (no separate changes needed)
- `flutter analyze` must pass with no issues after each task
- Preserve all existing timer/cue/phase logic — only change visual layout

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `lib/pages/workout_builder_player_page.dart` | Modify | Replace hero widgets, add exercise info section |

No new files needed — `_ExerciseHeroCard` is a private widget inside the builder player page.

---

### Task 1: Create `_ExerciseHeroCard` widget

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart` (add new class at bottom of file)

**Interfaces:**
- Consumes: `mediaPath` (String), `remainingSeconds` (int), `phaseLabel` (String), `isRestPhase` (bool), `palette` (List<Color>), `phaseBadge` (Widget)
- Produces: `_ExerciseHeroCard` widget used by `build()` method

- [ ] **Step 1: Add the `_ExerciseHeroCard` widget class**

Add at the bottom of `workout_builder_player_page.dart` (before the closing `}` of the file, after existing helper widgets):

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

  @override
  Widget build(BuildContext context) {
    final hasMedia = !isRestPhase && mediaPath.trim().isNotEmpty;

    if (!hasMedia && !isRestPhase) {
      return CircularCountdown(
        progress: 0,
        seconds: remainingSeconds,
        phaseLabel: phaseLabel,
        subtitle: '${remainingSeconds}s',
        gradient: palette,
      );
    }

    return SizedBox(
      height: 280,
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
                colors: [Colors.transparent, Colors.black54],
                stops: [0.4, 1.0],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: phaseBadge,
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
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
                ),
                const SizedBox(height: 4),
                Text(
                  phaseLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
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
          Icons.self_improvement_rounded,
          color: Colors.white.withValues(alpha: 0.2),
          size: 64,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat(builder): add _ExerciseHeroCard widget with GIF/rest/fallback states"
```

---

### Task 2: Replace hero in build method

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart` (modify `build()` method)

**Interfaces:**
- Consumes: `_ExerciseHeroCard` from Task 1
- Produces: Updated `build()` method using new hero

- [ ] **Step 1: Update build method to use _ExerciseHeroCard**

In the `build()` method, replace the `_BuilderHeroSessionCard` section (around lines 613-627) with:

```dart
                        _ExerciseHeroCard(
                          mediaPath: current.type == _BuilderPhaseType.work
                              ? current.exercise.mediaPath
                              : '',
                          remainingSeconds: _remainingSeconds,
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
                            accent: current.type == _BuilderPhaseType.rest
                                ? const Color(0xFF60A5FA)
                                : const Color(0xFF22C55E),
                          ),
                        ),
```

- [ ] **Step 2: Remove _ExerciseMediaPreview usage**

Remove the `_ExerciseMediaPreview` widget usage in the build method (around lines 640-648). Replace with exercise info section:

```dart
                        const SizedBox(height: 12),
                        if (!_isComplete) ...[
                          Text(
                            current.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Next: ${nextPhase.label} (${nextPhase.durationSeconds}s)',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.54),
                              fontSize: 14,
                            ),
                          ),
                        ],
```

- [ ] **Step 3: Remove _BuilderHeroSessionCard class**

Delete the entire `_BuilderHeroSessionCard` class from the file (it's no longer used).

- [ ] **Step 4: Remove _ExerciseMediaPreview class**

Delete the entire `_ExerciseMediaPreview` class from the file (it's no longer used).

- [ ] **Step 5: Remove _RestPhaseMessageCard class if unused**

Check if `_RestPhaseMessageCard` is still referenced. If not, delete it.

- [ ] **Step 6: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 7: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat(builder): replace circular countdown hero with GIF hero layout"
```

---

### Task 3: Final verification

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
1. Work phase with GIF shows GIF hero with timer overlay
2. Work phase without GIF falls back to circular countdown
3. Rest phase shows gradient + rest icon + timer
4. Exercise name and next phase info display below hero
5. All 4 controls work (Start/Pause, Skip, Reset, Music Toggle)
6. Timer/cue logic is unchanged

- [ ] **Step 3: Final commit if needed**

```bash
git add -A
git commit -m "chore: finalize builder player GIF hero layout"
```
