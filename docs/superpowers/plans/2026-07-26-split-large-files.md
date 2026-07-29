# Split Large Files Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reduce file sizes by extracting private widgets from oversized page files into dedicated widget files.

**Architecture:** Extract private widget classes from `workout_timer_page.dart` (82KB → ~30KB) and `workout_builder_player_page.dart` (51KB → ~20KB) into new public widget files. Widgets that are only used within a single page become public but stay page-scoped (in a widgets/ subfolder named after the page).

**Tech Stack:** Flutter/Dart, existing design system

## Global Constraints

- Flutter 3.44.2, Dart 3.12.2
- Must not break existing widget APIs or page behavior
- Design system: dark theme, `Color(0xFFFF8A1E)` accent, `Colors.white.withValues(alpha:)` backgrounds
- All extracted widgets must remain functionally identical
- Follow existing code style — no new patterns introduced

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `lib/widgets/timer_guide_cards.dart` | Guide cards extracted from workout_timer_page.dart |
| Create | `lib/widgets/timer_config_widgets.dart` | Config panels/sliders extracted from workout_timer_page.dart |
| Create | `lib/widgets/builder_player_widgets.dart` | Overlays/controls extracted from workout_builder_player_page.dart |
| Modify | `lib/pages/workout_timer_page.dart` | Remove extracted private widgets, add imports |
| Modify | `lib/pages/workout_builder_player_page.dart` | Remove extracted private widgets, add imports |

---

### Task 1: Extract guide cards from workout_timer_page.dart

**Files:**
- Create: `lib/widgets/timer_guide_cards.dart`
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `WorkoutPhase`, `WorkoutPhaseType` from `lib/models/workout_models.dart`
- Produces: `CalisthenicsGuideCard`, `Vo2MaxGuideCard`, `HiitGuideCard`, `TabataGuideCard`, `Vo2PhaseRow`, `GuideSection`, `PhaseMusicProfile` (public classes)

- [ ] **Step 1: Create timer_guide_cards.dart with extracted widgets**

Read `lib/pages/workout_timer_page.dart` lines 1575-2089 to get the exact code for these classes:
- `_PhaseMusicProfile` (line 1575) → rename to `PhaseMusicProfile`
- `_CalisthenicsGuideCard` (line 1589) → rename to `CalisthenicsGuideCard`
- `_Vo2MaxGuideCard` (line 1692) → rename to `Vo2MaxGuideCard`
- `_HiitGuideCard` (line 1822) → rename to `HiitGuideCard`
- `_TabataGuideCard` (line 1924) → rename to `TabataGuideCard`
- `_Vo2PhaseRow` (line 2019) → rename to `Vo2PhaseRow`
- `_GuideSection` (line 2090) → rename to `GuideSection`

Create `lib/widgets/timer_guide_cards.dart` with these classes. Add required imports at top:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
```

Copy each class exactly as-is but remove the `_` prefix (make them public).

- [ ] **Step 2: Update workout_timer_page.dart**

Remove the extracted classes (lines 1575-2141) from `workout_timer_page.dart`. Add import:

```dart
import 'package:my_app/widgets/timer_guide_cards.dart';
```

- [ ] **Step 3: Verify and commit**

Run: `flutter analyze lib/pages/workout_timer_page.dart lib/widgets/timer_guide_cards.dart`
Expected: No issues

Commit: `refactor: extract guide cards from workout_timer_page`

---

### Task 2: Extract config widgets from workout_timer_page.dart

**Files:**
- Create: `lib/widgets/timer_config_widgets.dart`
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `AudioEngine` from `lib/services/audio_engine.dart`, `WorkoutFingerprint` from `lib/models/workout_fingerprint.dart`
- Produces: `CustomizationToggleCard`, `ConfigPanel`, `LabeledSlider`, `CueToggleTile`, `PhaseTempoPanel` (public classes)

- [ ] **Step 1: Create timer_config_widgets.dart with extracted widgets**

Read `lib/pages/workout_timer_page.dart` lines 2143-2681 to get the exact code for these classes:
- `_CustomizationToggleCard` (line 2143) → rename to `CustomizationToggleCard`
- `_ConfigPanel` (line 2224) → rename to `ConfigPanel`
- `_LabeledSlider` (line 2455) → rename to `LabeledSlider`
- `_CueToggleTile` (line 2511) → rename to `CueToggleTile`
- `_PhaseTempoPanel` (line 2561) → rename to `PhaseTempoPanel`

Create `lib/widgets/timer_config_widgets.dart` with these classes. Add required imports:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/services/audio_engine.dart';
import 'package:my_app/models/workout_fingerprint.dart';
```

Copy each class exactly as-is but remove the `_` prefix.

- [ ] **Step 2: Update workout_timer_page.dart**

Remove the extracted classes (lines 2143-2681) from `workout_timer_page.dart`. Add import:

```dart
import 'package:my_app/widgets/timer_config_widgets.dart';
```

- [ ] **Step 3: Verify and commit**

Run: `flutter analyze lib/pages/workout_timer_page.dart lib/widgets/timer_config_widgets.dart`
Expected: No issues

Commit: `refactor: extract config widgets from workout_timer_page`

---

### Task 3: Extract builder player widgets

**Files:**
- Create: `lib/widgets/builder_player_widgets.dart`
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `CountdownBar` from `lib/widgets/countdown_bar.dart`, `WorkoutIntensity` from `lib/models/workout_models.dart`
- Produces: `ExerciseHeroCard`, `InfoColumn`, `InfoCard`, `ControlBar`, `BuilderCompletionOverlay`, `BuilderPauseOverlay`, `BuilderPauseButton`, `CompletionStat`, `MusicChip` (public classes)

- [ ] **Step 1: Create builder_player_widgets.dart with extracted widgets**

Read `lib/pages/workout_builder_player_page.dart` lines 882-1572 to get the exact code for these classes:
- `_ExerciseHeroCard` (line 882) → rename to `ExerciseHeroCard`
- `_InfoColumn` (line 988) → rename to `InfoColumn`
- `_InfoCard` (line 1032) → rename to `InfoCard`
- `_ControlBar` (line 1084) → rename to `ControlBar`
- `_BuilderCompletionOverlay` (line 1239) → rename to `BuilderCompletionOverlay`
- `_BuilderPauseOverlay` (line 1367) → rename to `BuilderPauseOverlay`
- `_BuilderPauseButton` (line 1431) → rename to `BuilderPauseButton`
- `_CompletionStat` (line 1485) → rename to `CompletionStat`
- `_MusicChip` (line 1528) → rename to `MusicChip`

Create `lib/widgets/builder_player_widgets.dart` with these classes. Add required imports:

```dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:my_app/widgets/countdown_bar.dart';
import 'package:my_app/models/workout_models.dart';
```

Copy each class exactly as-is but remove the `_` prefix.

- [ ] **Step 2: Update workout_builder_player_page.dart**

Remove the extracted classes (lines 882-1572) from `workout_builder_player_page.dart`. Add import:

```dart
import 'package:my_app/widgets/builder_player_widgets.dart';
```

- [ ] **Step 3: Verify and commit**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart lib/widgets/builder_player_widgets.dart`
Expected: No issues

Commit: `refactor: extract widgets from workout_builder_player_page`

---

### Task 4: Final verification

**Files:** None (read-only verification)

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze lib/`
Expected: No new issues (same pre-existing warnings only)

- [ ] **Step 2: Build Windows**

Run: `flutter build windows --debug`
Expected: Build succeeds

- [ ] **Step 3: Report file sizes**

Run: `Get-ChildItem -Recurse lib -File | Sort-Object Length -Descending | Select-Object -First 10 Name, @{N='KB';E={[math]::Round($_.Length/1024,1)}}`
Confirm both target files shrank significantly.
