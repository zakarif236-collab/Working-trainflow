# Builder Player UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the builder player to match the timer page's premium visual quality — animated gradients, circular countdown, glow effects, styled controls — and add countdown beep sounds.

**Architecture:** Extract shared visual widgets from the timer page into a reusable file, refactor the timer page to use them, then rewrite the builder player's build method with the same components. Add WAV-based countdown beep generation to CueService.

**Tech Stack:** Flutter, Dart, just_audio (WAV playback), flutter_tts (existing), dart:typed_data (WAV generation)

## Global Constraints

- Flutter project at `C:\Users\hp\my_app`
- No new asset files — beeps generated as WAV in memory
- No new dependencies — uses existing `just_audio` and `dart:typed_data`
- Existing `CircularCountdown` and `WorkoutTimeline` widgets reused as-is
- All business logic (timer, phases, cues, resume) untouched
- `flutter analyze` must pass with zero issues after each task

---

## File Structure

| File | Responsibility |
|------|---------------|
| `lib/services/cue_service.dart` | Add `playCountdownBeep()` and `playCountdownFinalBeep()` — WAV sine wave generation + playback |
| `lib/widgets/workout_player_widgets.dart` | **New** — shared visual widgets extracted from timer page: `GlowBlob`, `PhaseStatusBadge`, `NextPhaseCard`, `ProgressHeader`, `PlayerActionControls`, `PlayerControlButton`, `PhaseBadge` |
| `lib/pages/workout_timer_page.dart` | Replace private widget usages with imports from shared file, add countdown beeps |
| `lib/pages/workout_builder_player_page.dart` | Full rewrite of `build()`, add animation controller, phase palette, countdown beeps, GIF/image box integration |

---

### Task 1: Add Countdown Beep Methods to CueService

**Files:**
- Modify: `lib/services/cue_service.dart`

**Interfaces:**
- Consumes: `_cachePlayer` (existing `AudioPlayer?` from `just_audio`)
- Produces: `Future<void> playCountdownBeep()` and `Future<void> playCountdownFinalBeep()` on `CueService`

- [ ] **Step 1: Add WAV generation helper to CueService**

Add these private methods to the `CueService` class in `lib/services/cue_service.dart`, after the `_buildPromptKey` method (around line 290):

```dart
Future<void> _playGeneratedBeep({
  required double frequencyHz,
  required int durationMs,
  required double volume,
}) async {
  await _ensureEnginesReady();
  final player = _cachePlayer;
  if (player == null) {
    return;
  }

  final sampleRate = 22050;
  final numSamples = (sampleRate * durationMs / 1000).round();
  final data = _generateSineWaveWav(
    frequencyHz: frequencyHz,
    sampleRate: sampleRate,
    numSamples: numSamples,
    volume: volume,
  );

  final tempDir = await getTemporaryDirectory();
  final file = File(
    '${tempDir.path}${Platform.pathSeparator}beep_${frequencyHz.round()}_${durationMs}.wav',
  );
  await file.writeAsBytes(data, flush: true);

  try {
    await player.setFilePath(file.path);
    await player.play();
  } catch (_) {
    // Beep playback is best-effort
  }
}

Uint8List _generateSineWaveWav({
  required double frequencyHz,
  required int sampleRate,
  required int numSamples,
  required double volume,
}) {
  final amplitude = (volume * 32767).round().clamp(-32768, 32767);
  final byteRate = sampleRate * 1 * 2;
  final dataSize = numSamples * 2;
  final fileSize = 36 + dataSize;

  final buffer = ByteData(44 + dataSize);
  var offset = 0;

  // RIFF header
  buffer.setUint8(offset, 0x52); offset++; // R
  buffer.setUint8(offset, 0x49); offset++; // I
  buffer.setUint8(offset, 0x46); offset++; // F
  buffer.setUint8(offset, 0x46); offset++; // F
  buffer.setUint32(offset, fileSize, Endian.little); offset += 4;
  buffer.setUint8(offset, 0x57); offset++; // W
  buffer.setUint8(offset, 0x41); offset++; // A
  buffer.setUint8(offset, 0x56); offset++; // V
  buffer.setUint8(offset, 0x45); offset++; // E

  // fmt chunk
  buffer.setUint8(offset, 0x66); offset++; // f
  buffer.setUint8(offset, 0x6D); offset++; // m
  buffer.setUint8(offset, 0x74); offset++; // t
  buffer.setUint8(offset, 0x20); offset++; // (space)
  buffer.setUint32(offset, 16, Endian.little); offset += 4; // chunk size
  buffer.setUint16(offset, 1, Endian.little); offset += 2; // PCM
  buffer.setUint16(offset, 1, Endian.little); offset += 2; // mono
  buffer.setUint32(offset, sampleRate, Endian.little); offset += 4;
  buffer.setUint32(offset, byteRate, Endian.little); offset += 4;
  buffer.setUint16(offset, 2, Endian.little); offset += 2; // block align
  buffer.setUint16(offset, 16, Endian.little); offset += 2; // bits per sample

  // data chunk
  buffer.setUint8(offset, 0x64); offset++; // d
  buffer.setUint8(offset, 0x61); offset++; // a
  buffer.setUint8(offset, 0x74); offset++; // t
  buffer.setUint8(offset, 0x61); offset++; // a
  buffer.setUint32(offset, dataSize, Endian.little); offset += 4;

  // Generate sine wave samples with fade-out
  final twoPiFOverSr = 2.0 * 3.141592653589793 * frequencyHz / sampleRate;
  for (var i = 0; i < numSamples; i++) {
    final fadeOut = (1.0 - i / numSamples);
    final sample = (amplitude * Math.sin(twoPiFOverSr * i) * fadeOut).round();
    buffer.setInt16(offset, sample.clamp(-32768, 32767), Endian.little);
    offset += 2;
  }

  final bytes = Uint8List(44 + dataSize);
  final byteBuffer = buffer.buffer.asByteData();
  for (var i = 0; i < bytes.length; i++) {
    bytes[i] = byteBuffer.getUint8(i);
  }
  return bytes;
}
```

Add the import at the top of `cue_service.dart` if not already present:

```dart
import 'dart:math' as Math;
import 'dart:typed_data';
```

- [ ] **Step 2: Add public beep methods**

Add these two public methods to the `CueService` class, after `playWorkoutCompletionBeep()`:

```dart
Future<void> playCountdownBeep() async {
  await _playGeneratedBeep(
    frequencyHz: 880,
    durationMs: 100,
    volume: 0.7,
  );
}

Future<void> playCountdownFinalBeep() async {
  await _playGeneratedBeep(
    frequencyHz: 1320,
    durationMs: 200,
    volume: 1.0,
  );
}
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze lib/services/cue_service.dart`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/services/cue_service.dart
git commit -m "feat: add countdown beep sounds to CueService"
```

---

### Task 2: Extract Shared Widgets to WorkoutPlayerWidgets

**Files:**
- Create: `lib/widgets/workout_player_widgets.dart`
- Modify: `lib/pages/workout_timer_page.dart` (remove extracted private widgets)

**Interfaces:**
- Consumes: Nothing from earlier tasks
- Produces: Public widgets `GlowBlob`, `PhaseStatusBadge`, `NextPhaseCard`, `ProgressHeader`, `PlayerActionControls`, `PlayerControlButton`, `PhaseBadge`

- [ ] **Step 1: Create the shared widgets file**

Create `lib/widgets/workout_player_widgets.dart` with these widgets copied from `workout_timer_page.dart` but made public (remove underscore prefix):

```dart
import 'package:flutter/material.dart';

class GlowBlob extends StatelessWidget {
  const GlowBlob({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      height: 240,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}

class PhaseStatusBadge extends StatelessWidget {
  const PhaseStatusBadge({super.key, required this.isRunning});

  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isRunning
            ? const Color(0xFF22C55E).withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isRunning
              ? const Color(0xFF22C55E).withValues(alpha: 0.30)
              : Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRunning ? const Color(0xFF22C55E) : Colors.white54,
              boxShadow: isRunning
                  ? [
                      BoxShadow(
                        color: const Color(0xFF22C55E).withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isRunning ? 'Running' : 'Ready',
            style: TextStyle(
              color: isRunning ? const Color(0xFF22C55E) : Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class NextPhaseCard extends StatelessWidget {
  const NextPhaseCard({super.key, required this.phase});

  final NextPhaseCardData phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFFB15C),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Up Next',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phase.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${phase.durationSeconds}s${phase.setNumber == null ? '' : ' | Set ${phase.setNumber}'}',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NextPhaseCardData {
  const NextPhaseCardData({
    required this.label,
    required this.durationSeconds,
    this.setNumber,
  });

  final String label;
  final int durationSeconds;
  final int? setNumber;
}

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.progress,
    required this.elapsed,
    required this.total,
  });

  final double progress;
  final int elapsed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.bar_chart_rounded, color: Color(0xFFFF8A1E), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Workout Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFFB15C),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A1E)),
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${_formatSeconds(elapsed)} / ${_formatSeconds(total)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatSeconds(int value) {
    final m = value ~/ 60;
    final s = value % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class PlayerActionControls extends StatelessWidget {
  const PlayerActionControls({
    super.key,
    required this.running,
    required this.complete,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
  });

  final bool running;
  final bool complete;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: PlayerControlButton(
                label: running ? 'Pause' : complete ? 'Restart' : 'Start',
                icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                primary: true,
                onPressed: onStartPause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: PlayerControlButton(
                label: 'Skip',
                icon: Icons.skip_next_rounded,
                primary: false,
                onPressed: onSkip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: PlayerControlButton(
                label: 'Reset',
                icon: Icons.replay_rounded,
                primary: false,
                onPressed: onReset,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox.shrink()),
          ],
        ),
      ],
    );
  }
}

class PlayerControlButton extends StatelessWidget {
  const PlayerControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: primary
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A1E), Color(0xFFFF6B1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8A1E).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                icon: Icon(icon),
                label: Text(label),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class PhaseBadge extends StatelessWidget {
  const PhaseBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.30)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: accent, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Run flutter analyze on the new file**

Run: `flutter analyze lib/widgets/workout_player_widgets.dart`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/workout_player_widgets.dart
git commit -m "feat: extract shared player widgets to workout_player_widgets.dart"
```

---

### Task 3: Refactor Timer Page to Use Shared Widgets

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `GlowBlob`, `NextPhaseCard`, `NextPhaseCardData`, `ProgressHeader`, `PlayerActionControls`, `PlayerControlButton`, `PhaseBadge` from Task 2
- Produces: Timer page continues to work identically, now using shared widgets

- [ ] **Step 1: Add import for shared widgets**

Add at the top of `workout_timer_page.dart` after the existing imports:

```dart
import 'package:my_app/widgets/workout_player_widgets.dart';
```

- [ ] **Step 2: Remove private widget classes that are now shared**

Delete these private classes from `workout_timer_page.dart`:
- `_GlowBlob` (search for `class _GlowBlob`)
- `_NextPhaseCard` (search for `class _NextPhaseCard`)
- `_ProgressHeader` (search for `class _ProgressHeader`)
- `_ActionControls` (search for `class _ActionControls`)
- `_ControlButton` (search for `class _ControlButton`)
- `_PhaseBadge` (search for `class _PhaseBadge`)

- [ ] **Step 3: Update references in the timer page build method**

Replace these references in the build method:
- `_GlowBlob(color: ...)` → `GlowBlob(color: ...)`
- `_NextPhaseCard(phase: ...)` → `NextPhaseCard(phase: NextPhaseCardData(label: ..., durationSeconds: ..., setNumber: ...))`
- `_ProgressHeader(...)` → `ProgressHeader(...)`
- `_ActionControls(...)` → `PlayerActionControls(...)`
- `_PhaseBadge(...)` → `PhaseBadge(...)`

For the `_NextPhaseCard` specifically, the timer page currently passes a `WorkoutPhase` object. Update it to pass a `NextPhaseCardData` instead:

Find the line `_NextPhaseCard(phase: nextPhase)` and replace with:
```dart
NextPhaseCard(
  phase: NextPhaseCardData(
    label: nextPhase.label,
    durationSeconds: nextPhase.durationSeconds,
    setNumber: nextPhase.setNumber,
  ),
),
```

- [ ] **Step 4: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No issues found

- [ ] **Step 5: Verify the timer page still compiles and renders**

Run: `flutter analyze`
Expected: No issues found across the whole project

- [ ] **Step 6: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "refactor: timer page uses shared player widgets"
```

---

### Task 4: Rewrite Builder Player UI

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `GlowBlob`, `PhaseStatusBadge`, `NextPhaseCard`, `NextPhaseCardData`, `ProgressHeader`, `PlayerActionControls`, `PhaseBadge` from Task 2; `CircularCountdown` from `lib/widgets/circular_countdown.dart`; `WorkoutTimeline` from `lib/widgets/workout_timeline.dart`
- Produces: Fully redesigned builder player with animated gradients, circular countdown, glow effects, styled controls

- [ ] **Step 1: Add imports and mixins**

Add these imports at the top of `workout_builder_player_page.dart`:

```dart
import 'package:my_app/widgets/circular_countdown.dart';
import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/workout_timeline.dart';
```

Change the state class declaration from:

```dart
class _WorkoutBuilderPlayerPageState extends State<WorkoutBuilderPlayerPage> {
```

to:

```dart
class _WorkoutBuilderPlayerPageState extends State<WorkoutBuilderPlayerPage>
    with SingleTickerProviderStateMixin {
```

- [ ] **Step 2: Add animation controller and phase palette**

Add these fields to `_WorkoutBuilderPlayerPageState`:

```dart
late final AnimationController _pulseController;
```

In `initState()`, add after `super.initState();`:

```dart
_pulseController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 800),
  lowerBound: 0.97,
  upperBound: 1.03,
);
```

In `dispose()`, add before `super.dispose();`:

```dart
_pulseController.dispose();
```

In the `_start()` method, after `setState(() { _isRunning = true; });`, add:

```dart
_pulseController.repeat(reverse: true);
```

In the `_pause()` method, after `setState(() { _isRunning = false; });`, add:

```dart
_pulseController.stop();
_pulseController.value = 1;
```

In `_stopAndReset()`, after the setState block, add:

```dart
_pulseController.stop();
_pulseController.value = 1;
```

Add this getter to `_WorkoutBuilderPlayerPageState`:

```dart
List<Color> get _phasePalette {
  switch (_currentPhase.type) {
    case _BuilderPhaseType.work:
      return const [Color(0xFF8B1A2A), Color(0xFFFF5A5F)];
    case _BuilderPhaseType.rest:
      return const [Color(0xFF0E4D6B), Color(0xFF2AB7CA)];
    case _BuilderPhaseType.complete:
      return const [Color(0xFF333333), Color(0xFF666666)];
  }
}

_BuilderPhase get _nextPhase {
  final nextIndex = _phaseIndex + 1;
  if (nextIndex < _timeline.length) {
    return _timeline[nextIndex];
  }
  return _currentPhase;
}
```

- [ ] **Step 3: Replace the build method**

Replace the entire `build()` method (from `@override Widget build(BuildContext context) {` to the matching closing brace) with:

```dart
@override
Widget build(BuildContext context) {
  final routine = _routine;
  if (routine == null) {
    return Scaffold(
      appBar: AppBar(title: const Text('Workout')),
      body: const Center(
        child: Text('Unable to load workout.'),
      ),
    );
  }

  final current = _currentPhase;
  final isRest = current.type == _BuilderPhaseType.rest;
  final palette = _phasePalette;

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
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -30,
            child: GlowBlob(color: palette.first.withValues(alpha: 0.55)),
          ),
          Positioned(
            bottom: -80,
            right: -40,
            child: GlowBlob(color: palette.last.withValues(alpha: 0.45)),
          ),
          SafeArea(
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(
                              Icons.arrow_back_rounded,
                              color: Colors.white,
                            ),
                            tooltip: 'Back',
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
                              _isComplete
                                  ? 'Session complete'
                                  : _isRunning
                                      ? 'Workout in progress'
                                      : 'Build focus. Push limits. See results.',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white54,
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
                      const SizedBox(height: 8),
                      // Hero Session Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                          boxShadow: [
                            BoxShadow(
                              color: palette.first.withValues(alpha: 0.12),
                              blurRadius: 40,
                              spreadRadius: -4,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.25),
                              blurRadius: 24,
                              spreadRadius: -6,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Align(
                              alignment: Alignment.centerRight,
                              child: PhaseStatusBadge(isRunning: _isRunning),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 360),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: ScaleTransition(
                                  scale: _pulseController,
                                  child: CircularCountdown(
                                    progress: _phaseProgress,
                                    seconds: _remainingSeconds,
                                    phaseLabel: _isComplete
                                        ? 'Complete'
                                        : isRest
                                            ? 'Rest'
                                            : current.exercise.name,
                                    subtitle: '${_remainingSeconds}s',
                                    gradient: [palette.first, palette.last],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Row(
                              children: [
                                PhaseBadge(
                                  icon: Icons.local_fire_department_rounded,
                                  label: _isComplete
                                      ? 'Complete'
                                      : isRest
                                          ? 'Rest'
                                          : current.exercise.name,
                                  accent: palette.first,
                                ),
                                const SizedBox(width: 8),
                                PhaseBadge(
                                  icon: Icons.timer_rounded,
                                  label: '${_currentPhase.durationSeconds}s',
                                  accent: palette.last,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Action Controls
                      if (!_isComplete)
                        PlayerActionControls(
                          running: _isRunning,
                          complete: _isComplete,
                          onStartPause: _isRunning ? _pause : _start,
                          onReset: _stopAndReset,
                          onSkip: _skip,
                        ),
                      const SizedBox(height: 12),
                      // Up Next Card
                      if (!_isComplete)
                        NextPhaseCard(
                          phase: NextPhaseCardData(
                            label: _nextPhase.type == _BuilderPhaseType.rest
                                ? 'Rest'
                                : _nextPhase.exercise.name,
                            durationSeconds: _nextPhase.durationSeconds,
                          ),
                        ),
                      const SizedBox(height: 12),
                      // Exercise Media or Rest Message
                      if (!_isComplete)
                        isRest
                            ? const _RestPhaseMessageCard(
                                message: 'Take a deep breath. Recover and get ready for the next push.',
                              )
                            : _ExerciseMediaPreview(path: current.exercise.mediaPath),
                      const SizedBox(height: 12),
                      // Progress Header
                      ProgressHeader(
                        progress: _totalProgress,
                        elapsed: _elapsedSeconds,
                        total: _totalSeconds,
                      ),
                      const SizedBox(height: 12),
                      // Timeline
                      WorkoutTimeline(
                        timeline: _buildWorkoutTimeline(),
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
        ],
      ),
    ),
  );
}
```

- [ ] **Step 4: Add helper to convert builder timeline to WorkoutTimeline format**

The `WorkoutTimeline` widget expects `List<WorkoutPhase>`, but the builder player uses `_BuilderPhase`. Add this conversion method to `_WorkoutBuilderPlayerPageState`:

```dart
List<WorkoutPhase> _buildWorkoutTimeline() {
  return _timeline.asMap().entries.map((entry) {
    final phase = entry.value;
    return WorkoutPhase(
      type: phase.type == _BuilderPhaseType.work
          ? WorkoutPhaseType.work
          : phase.type == _BuilderPhaseType.rest
              ? WorkoutPhaseType.rest
              : WorkoutPhaseType.complete,
      label: phase.label,
      durationSeconds: phase.durationSeconds,
    );
  }).toList();
}
```

- [ ] **Step 5: Run flutter analyze**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No issues found

- [ ] **Step 6: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "feat: redesign builder player UI with premium visual style"
```

---

### Task 5: Wire Up Countdown Beeps in Both Pages

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `playCountdownBeep()` and `playCountdownFinalBeep()` from Task 1
- Produces: Countdown 5-4-3-2-1 produces beep sounds in both pages

- [ ] **Step 1: Update builder player countdown cues**

In `workout_builder_player_page.dart`, find the `_handleWorkoutCues()` method. Locate the countdown section that currently reads:

```dart
if (_remainingSeconds > 0 && _remainingSeconds <= 5) {
  if (_hapticCueEnabled) {
    if (_remainingSeconds <= 3) {
      await HapticFeedback.lightImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
  }
  if (_voiceCueEnabled) {
    try {
      await _cueService.speakCount(_remainingSeconds, shouldSpeak: true);
    } on CueServiceException catch (e) {
      _showMessage(e.message);
    }
  }
}
```

Replace it with:

```dart
if (_remainingSeconds > 0 && _remainingSeconds <= 5) {
  if (_hapticCueEnabled) {
    if (_remainingSeconds <= 3) {
      await HapticFeedback.lightImpact();
    } else {
      await HapticFeedback.selectionClick();
    }
  }
  if (_remainingSeconds == 1) {
    await _cueService.playCountdownFinalBeep();
  } else {
    await _cueService.playCountdownBeep();
  }
  if (_voiceCueEnabled) {
    try {
      await _cueService.speakCount(_remainingSeconds, shouldSpeak: true);
    } on CueServiceException catch (e) {
      _showMessage(e.message);
    }
  }
}
```

- [ ] **Step 2: Update timer page countdown cues**

In `workout_timer_page.dart`, find the `_handleWorkoutCues()` method. Locate the countdown section that currently reads:

```dart
if (_controller.isRunning && remaining != _lastAnnouncedSeconds) {
  _lastAnnouncedSeconds = remaining;
  if (remaining > 0 && remaining <= 5) {
    if (remaining <= 3 && _hapticCueEnabled) {
      await HapticFeedback.lightImpact();
    } else if (_hapticCueEnabled) {
      await HapticFeedback.selectionClick();
    }
    try {
      await _cueService.speakCount(remaining, shouldSpeak: canSpeak);
    } on CueServiceException catch (e) {
      _showMessage(e.message);
    }
  }
}
```

Replace it with:

```dart
if (_controller.isRunning && remaining != _lastAnnouncedSeconds) {
  _lastAnnouncedSeconds = remaining;
  if (remaining > 0 && remaining <= 5) {
    if (remaining <= 3 && _hapticCueEnabled) {
      await HapticFeedback.lightImpact();
    } else if (_hapticCueEnabled) {
      await HapticFeedback.selectionClick();
    }
    if (remaining == 1) {
      await _cueService.playCountdownFinalBeep();
    } else {
      await _cueService.playCountdownBeep();
    }
    try {
      await _cueService.speakCount(remaining, shouldSpeak: canSpeak);
    } on CueServiceException catch (e) {
      _showMessage(e.message);
    }
  }
}
```

- [ ] **Step 3: Run flutter analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 4: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart lib/pages/workout_timer_page.dart
git commit -m "feat: add countdown beep sounds to builder player and timer"
```

---

### Task 6: Final Verification

**Files:** None (verification only)

- [ ] **Step 1: Run full project analyze**

Run: `flutter analyze`
Expected: No issues found

- [ ] **Step 2: Manual verification checklist**

Verify each of these by building and running the app:
1. Builder player: animated gradient background changes with work/rest/complete phases
2. Builder player: circular countdown pulses while running
3. Builder player: glowing "Running" / "Ready" status badge
4. Builder player: "Up Next" card shows next exercise
5. Builder player: exercise GIF/image displays during work phases
6. Builder player: rest message shows during rest phases
7. Builder player: progress header with percentage and elapsed/total
8. Builder player: horizontal timeline renders correctly
9. Builder player: Start/Pause, Skip, Reset buttons styled correctly
10. Builder player: back button works
11. Builder player: countdown 5-4-3-2-1 produces beep sounds
12. Builder player: second 1 has a distinct higher-pitched beep
13. Timer page: all existing functionality still works
14. Timer page: countdown beeps work identically

- [ ] **Step 3: Final commit if any cleanup needed**

```bash
git add -A
git commit -m "chore: builder player UI redesign complete"
```
