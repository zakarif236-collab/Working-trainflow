# Music System Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unified music controls across all timer screens with play/pause/skip/stop, proper ducking, and reactive UI.

**Architecture:** Add reactive notifiers to MusicService, create a reusable MusicControls widget with animated state transitions, extract shared picker logic into a mixin, fix AudioEngine ducking in WorkoutTimerPage, and wire music to HomeTimerLayout.

**Tech Stack:** Flutter/Dart, just_audio, on_audio_query, ValueNotifier pattern

## Global Constraints

- Flutter 3.44.2, Dart 3.12.2
- Design system: dark theme, `Color(0xFFFF8A1E)` accent, `Colors.white.withValues(alpha:)` backgrounds
- Must not break existing widget APIs
- Music must NEVER restart automatically on phase change
- Music continues seamlessly across exercise/rest/warmup/cooldown/pause/resume

---

### Task 1: Add reactive notifiers to MusicService

**Files:**
- Modify: `lib/services/music_service.dart`

**Interfaces:**
- Consumes: existing AudioPlayer, SongModel
- Produces: `playingNotifier` (ValueNotifier<bool>), `songNotifier` (ValueNotifier<SongModel?>)

- [ ] **Step 1: Add ValueNotifier fields**

In `lib/services/music_service.dart`, after line 20 (`int _playlistIndex = -1;`), add:

```dart
final ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
final ValueNotifier<SongModel?> songNotifier = ValueNotifier<SongModel?>(null);
```

- [ ] **Step 2: Update notifiers in playSong()**

In `playSong()` method, after `_currentSong = song;` (around line 90), add:

```dart
songNotifier.value = song;
```

After `_player.play();` (around line 89), add:

```dart
playingNotifier.value = true;
```

- [ ] **Step 3: Update notifiers in stop()**

In `stop()` method, after `_currentSong = null;` (around line 155), add:

```dart
songNotifier.value = null;
playingNotifier.value = false;
```

- [ ] **Step 4: Update notifiers in togglePlayPause()**

In `togglePlayPause()`, after `_player.pause();` add `playingNotifier.value = false;`
After `_player.play();` add `playingNotifier.value = true;`

- [ ] **Step 5: Update dispose()**

In `dispose()`, add before `_player.dispose()`:

```dart
playingNotifier.dispose();
songNotifier.dispose();
```

- [ ] **Step 6: Verify**

Run: `flutter analyze lib/services/music_service.dart`
Expected: No issues

- [ ] **Step 7: Commit**

```bash
git add lib/services/music_service.dart
git commit -m "feat: add reactive notifiers to MusicService"
```

---

### Task 2: Create MusicControls widget

**Files:**
- Create: `lib/widgets/music_controls.dart`

**Interfaces:**
- Consumes: `MusicService` from `lib/services/music_service.dart`
- Produces: `MusicControls` widget (public)

- [ ] **Step 1: Create MusicControls widget**

Create `lib/widgets/music_controls.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:my_app/services/music_service.dart';

class MusicControls extends StatelessWidget {
  const MusicControls({
    super.key,
    required this.musicService,
    required this.onOpenPicker,
  });

  final MusicService musicService;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: musicService.playingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<SongModel?>(
          valueListenable: musicService.songNotifier,
          builder: (context, currentSong, _) {
            final hasSong = currentSong != null;

            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isPlaying || hasSong
                  ? _buildPlaybackControls(context, isPlaying, currentSong)
                  : _buildPickerButton(context),
            );
          },
        );
      },
    );
  }

  Widget _buildPickerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onOpenPicker,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: Colors.white70,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.music_note_rounded, size: 20),
        label: const Text(
          'Play Music',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(
    BuildContext context,
    bool isPlaying,
    SongModel? song,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A1E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF8A1E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note_rounded,
            color: const Color(0xFFFF8A1E),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              song?.title ?? 'Music',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await musicService.togglePlayPause();
            },
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () async {
              await musicService.next();
            },
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () async {
              await musicService.stop();
            },
            icon: const Icon(Icons.stop_rounded, color: Colors.white),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/widgets/music_controls.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/music_controls.dart
git commit -m "feat: add MusicControls widget with play/pause/skip/stop"
```

---

### Task 3: Fix AudioEngine ducking in WorkoutTimerPage

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `_musicService` (already exists at line 78)
- Produces: AudioEngine receives `music:` parameter

- [ ] **Step 1: Pass music to AudioEngine**

In `lib/pages/workout_timer_page.dart`, find the AudioEngine creation (around lines 116-118):

```dart
_audioEngine = AudioEngine(
  voice: GeminiVoiceService(),
  sfx: SfxService(),
);
```

Change to:

```dart
_audioEngine = AudioEngine(
  voice: GeminiVoiceService(),
  sfx: SfxService(),
  music: _musicService,
);
```

- [ ] **Step 2: Verify**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No issues

- [ ] **Step 3: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "fix: pass MusicService to AudioEngine for ducking in WorkoutTimerPage"
```

---

### Task 4: Wire music to HomeTimerLayout

**Files:**
- Modify: `lib/widgets/home_timer_layout.dart`
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `MusicControls` widget, music params from WorkoutTimerPage
- Produces: HomeTimerLayout accepts music params

- [ ] **Step 1: Add music params to HomeTimerLayout constructor**

In `lib/widgets/home_timer_layout.dart`, find the constructor and add:

```dart
const HomeTimerLayout({
  super.key,
  // ... existing params ...
  this.musicControls,
});

final Widget? musicControls;
```

- [ ] **Step 2: Add MusicControls to HomeTimerLayout build()**

In the `build()` method, find the `ActionControls` widget. Add `musicControls` below it:

After the `ActionControls` widget, add:

```dart
if (musicControls != null) ...[
  const SizedBox(height: 12),
  musicControls!,
],
```

- [ ] **Step 3: Remove hardcoded music no-op from ActionControls in HomeTimerLayout**

In `ActionControls` call within HomeTimerLayout, keep the existing no-op since MusicControls handles it separately.

- [ ] **Step 4: Pass music controls from WorkoutTimerPage to HomeTimerLayout**

In `lib/pages/workout_timer_page.dart`, find `_buildHomeLayout()` method. Add the MusicControls widget as a parameter:

```dart
musicControls: MusicControls(
  musicService: _musicService,
  onOpenPicker: _openMusicPicker,
),
```

Add import at top of file:

```dart
import 'package:my_app/widgets/music_controls.dart';
```

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/pages/workout_timer_page.dart lib/widgets/home_timer_layout.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/home_timer_layout.dart lib/pages/workout_timer_page.dart
git commit -m "feat: wire music controls to HomeTimerLayout"
```

---

### Task 5: Replace music UI in WorkoutTimerLayout with MusicControls

**Files:**
- Modify: `lib/widgets/workout_timer_layout.dart`
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `MusicControls` widget
- Produces: WorkoutTimerLayout accepts `musicControls` param

- [ ] **Step 1: Add musicControls param to WorkoutTimerLayout**

In `lib/widgets/workout_timer_layout.dart`, add to constructor:

```dart
this.musicControls,
```

Add field:

```dart
final Widget? musicControls;
```

- [ ] **Step 2: Replace ActionControls music params with MusicControls widget**

In `build()` method, after `ActionControls`, add:

```dart
if (musicControls != null) ...[
  const SizedBox(height: 12),
  musicControls!,
],
```

Remove the old music-related params from `ActionControls` call (onMusicToggle, isMusicPlaying, songName) since MusicControls handles them now. Keep ActionControls with only: running, complete, onStartPause, onReset, onSkip.

- [ ] **Step 3: Update WorkoutTimerPage to pass MusicControls**

In `lib/pages/workout_timer_page.dart`, find `_buildWorkoutLayout()`. Replace the old music params:

Remove:
```dart
onMusicToggle: _toggleMusic,
isMusicPlaying: _musicService.player.playing,
selectedSongTitle: _musicService.currentSong?.title,
loadingSongs: _loadingSongs,
onMusicPickerTap: _openMusicPicker,
songName: _musicService.currentSong?.title,
```

Add:
```dart
musicControls: MusicControls(
  musicService: _musicService,
  onOpenPicker: _openMusicPicker,
),
```

- [ ] **Step 4: Remove _MusicChip from WorkoutTimerLayout header**

Remove the `_MusicChip` widget from the header Row in WorkoutTimerLayout (lines 149-154) since MusicControls handles everything.

Remove the `_MusicChip` class definition (lines 505-548).

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/pages/workout_timer_page.dart lib/widgets/workout_timer_layout.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add lib/widgets/workout_timer_layout.dart lib/pages/workout_timer_page.dart
git commit -m "feat: replace music UI with MusicControls in WorkoutTimerLayout"
```

---

### Task 6: Replace music UI in WorkoutBuilderPlayerPage with MusicControls

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`
- Modify: `lib/widgets/builder_player_widgets.dart`

**Interfaces:**
- Consumes: `MusicControls` widget
- Produces: Builder player uses unified controls

- [ ] **Step 1: Replace _MusicChip in builder player header with MusicControls**

In `lib/pages/workout_builder_player_page.dart`, find the header Row with `_MusicChip`. Replace it:

Remove:
```dart
_MusicChip(
  loading: _loadingSongs,
  onTap: _openMusicPicker,
  selectedSongTitle: _musicService.currentSong?.title,
),
```

Replace with:
```dart
Expanded(
  child: MusicControls(
    musicService: _musicService,
    onOpenPicker: _openMusicPicker,
  ),
),
```

Add import:
```dart
import 'package:my_app/widgets/music_controls.dart';
```

- [ ] **Step 2: Remove music params from _ControlBar**

In the `_ControlBar` widget in `lib/widgets/builder_player_widgets.dart`, remove the music-related params:
- Remove: `onMusicToggle`, `isMusicPlaying`, `songName`
- Remove: the music button from `_ControlBar.build()`

- [ ] **Step 3: Update _ControlBar call site**

Remove music params from `_ControlBar` constructor call in `workout_builder_player_page.dart`.

- [ ] **Step 4: Remove _MusicChip class from builder_player_widgets.dart**

Remove the `_MusicChip` class (lines 1528-1572).

- [ ] **Step 5: Verify**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart lib/widgets/builder_player_widgets.dart`
Expected: No issues

- [ ] **Step 6: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart lib/widgets/builder_player_widgets.dart
git commit -m "feat: replace music UI with MusicControls in builder player"
```

---

### Task 7: Final verification

**Files:** None (read-only)

- [ ] **Step 1: Run full analyze**

Run: `flutter analyze lib/`
Expected: No new issues

- [ ] **Step 2: Build Android release APK**

Run: `flutter build apk --release --target-platform android-arm64`
Expected: Build succeeds

- [ ] **Step 3: Build Windows debug**

Run: `flutter build windows --debug`
Expected: Build succeeds

- [ ] **Step 4: Verify checklist**

Confirm:
- MusicControls widget renders on all 3 timer screens
- Play/pause/skip/stop buttons work
- Stop returns to Music icon
- Music continues across phases
- Ducking works (voice lowers music)
