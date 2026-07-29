# Music Icon Fix & Music Playback Integration

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore the music picker and toggle functionality in the workout timer page, add music support to the workout builder player page, and make the music icon toggle to a stop icon showing the track name when playing.

**Architecture:** The `MusicService` already exists and works (`lib/services/music_service.dart`). It was wired up in the old `Working-` version but the UI was removed during a widget refactoring. The fix restores the picker UI and connects the existing `ActionControls` music toggle to real `MusicService` methods. The builder player page needs the same music infrastructure added.

**Tech Stack:** Flutter, just_audio, on_audio_query, MusicService (existing)

## Global Constraints

- Flutter 3.44.2, Dart 3.12.2
- Existing design system: dark theme with `Color(0xFFFF8A1E)` accent, rounded corners (16-24px), `Colors.white.withValues(alpha: 0.06)` backgrounds
- `MusicService` is already instantiated in `workout_timer_page.dart` (line 111) - reuse it, don't create new instances
- `on_audio_query` requires Android media permissions (handled by `MusicService.initialize()`)
- The `_MusicChip` widget from `Working-/lib/pages/workout_timer_page.dart:938-982` is the reference implementation

---

## Task 1: Add music parameters to WorkoutTimerLayout

**Files:**
- Modify: `lib/widgets/workout_timer_layout.dart`

**Interfaces:**
- Consumes: existing layout parameters
- Produces: new optional parameters for music state that `workout_timer_page.dart` will pass

- [ ] **Step 1: Add music parameters to WorkoutTimerLayout**

Add these fields to `WorkoutTimerLayout`:

```dart
// In the constructor, add these optional params after canPop:
this.onMusicToggle,
this.isMusicPlaying = false,
this.selectedSongTitle,
this.loadingSongs = false,
this.onMusicPickerTap,

// Add these fields:
final VoidCallback? onMusicToggle;
final bool isMusicPlaying;
final String? selectedSongTitle;
final bool loadingSongs;
final VoidCallback? onMusicPickerTap;
```

- [ ] **Step 2: Add MusicChip to the header row**

In the `build()` method, inside the header `Row` (after the `Expanded` widget for title/subtitle, around line 136), add the music chip:

```dart
// After the Expanded widget for header text, before closing the Row:
if (onMusicPickerTap != null)
  _MusicChip(
    loading: loadingSongs,
    onTap: onMusicPickerTap!,
    selectedSongTitle: selectedSongTitle,
  ),
```

- [ ] **Step 3: Add _MusicChip widget at the bottom of workout_timer_layout.dart**

Copy from `Working-/lib/pages/workout_timer_page.dart:938-982` and add at the end of `workout_timer_layout.dart`:

```dart
class _MusicChip extends StatelessWidget {
  const _MusicChip({
    required this.loading,
    required this.onTap,
    required this.selectedSongTitle,
  });

  final bool loading;
  final VoidCallback onTap;
  final String? selectedSongTitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.library_music_rounded, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              selectedSongTitle == null ? 'Music' : 'Track set',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Pass music state to ActionControls**

In the `build()` method, replace the hardcoded `onMusicToggle: () {}` and `isMusicPlaying: false` (line 156-157) with:

```dart
onMusicToggle: onMusicToggle ?? () {},
isMusicPlaying: isMusicPlaying,
```

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze lib/widgets/workout_timer_layout.dart`
Expected: No errors

---

## Task 2: Wire up music in WorkoutTimerPage

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`

**Interfaces:**
- Consumes: `MusicService` (already instantiated at line 111), `WorkoutTimerLayout` (new music params from Task 1)
- Produces: music picker modal, toggle behavior, track name display

- [ ] **Step 1: Add music state variables**

After the existing state variables (around line 104), add:

```dart
List<SongModel> _songs = const [];
bool _loadingSongs = false;
```

Also add the import at the top of the file:

```dart
import 'package:on_audio_query/on_audio_query.dart';
```

(Check if `SongModel` is already available via existing imports - `MusicService` may already export it.)

- [ ] **Step 2: Add _openMusicPicker method**

Add this method to `_WorkoutTimerPageState` (copy from `Working-/lib/pages/workout_timer_page.dart:234-347`):

```dart
Future<void> _openMusicPicker() async {
  setState(() {
    _loadingSongs = true;
  });

  try {
    await _musicService.initialize();
    final songs = await _musicService.loadSongs();
    if (!mounted) {
      return;
    }

    setState(() {
      _songs = songs;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF111826),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 54,
                  height: 6,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    color: Colors.white24,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select Workout Track',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Pick a local song from your library',
                  style: TextStyle(color: Colors.white60),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    itemCount: _songs.length,
                    separatorBuilder: (_, index) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final song = _songs[index];
                      final selected = _musicService.currentSong?.id == song.id;
                      return ListTile(
                        leading: Icon(
                          selected
                              ? Icons.equalizer_rounded
                              : Icons.music_note_rounded,
                          color: selected
                              ? const Color(0xFF2AB7CA)
                              : Colors.white70,
                        ),
                        title: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          song.artist ?? 'Unknown artist',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white54),
                        ),
                        onTap: () async {
                          try {
                            await _musicService.playSong(song);
                            if (!context.mounted) {
                              return;
                            }
                            Navigator.pop(context);
                            setState(() {});
                          } on MusicServiceException catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(e.message)),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  } on MusicServiceException catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _loadingSongs = false;
      });
    }
  }
}
```

- [ ] **Step 3: Add _toggleMusic method**

```dart
void _toggleMusic() {
  if (_musicService.player.playing) {
    _musicService.togglePlayPause();
  } else if (_musicService.currentSong != null) {
    _musicService.togglePlayPause();
  } else {
    _openMusicPicker();
  }
  setState(() {});
}
```

- [ ] **Step 4: Update the WorkoutTimerLayout call**

In `_buildWorkoutLayout()` (around line 1213), add the music parameters to the `WorkoutTimerLayout` constructor:

```dart
return WorkoutTimerLayout(
  // ... existing params ...
  onMusicToggle: _toggleMusic,
  isMusicPlaying: _musicService.player.playing,
  selectedSongTitle: _musicService.currentSong?.title,
  loadingSongs: _loadingSongs,
  onMusicPickerTap: _openMusicPicker,
);
```

- [ ] **Step 5: Verify compilation**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: No errors

---

## Task 3: Update ActionControls to show track name when playing

**Files:**
- Modify: `lib/widgets/workout_player_widgets.dart`

**Interfaces:**
- Consumes: existing `ActionControls` parameters
- Produces: updated button label showing track name + stop icon when music is playing

- [ ] **Step 1: Add optional songName parameter**

In the `ActionControls` class (line 216), add:

```dart
const ActionControls({
  // ... existing params ...
  this.songName,
});

final String? songName;
```

- [ ] **Step 2: Update the music button to show track name and stop icon**

Replace the music button code (lines 263-297) with:

```dart
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: onMusicToggle,
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      foregroundColor: isMusicPlaying
          ? const Color(0xFFFF8A1E)
          : Colors.white70,
      backgroundColor: isMusicPlaying
          ? const Color(0xFFFF8A1E).withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.06),
      side: BorderSide(
        color: isMusicPlaying
            ? const Color(0xFFFF8A1E).withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    icon: Icon(
      isMusicPlaying ? Icons.stop_rounded : Icons.music_off_rounded,
      size: 20,
    ),
    label: Text(
      isMusicPlaying
          ? (songName != null ? 'Stop  ${songName!}' : 'Music Playing')
          : 'Play Music',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        letterSpacing: 0.2,
      ),
    ),
  ),
),
```

- [ ] **Step 3: Verify compilation**

Run: `flutter analyze lib/widgets/workout_player_widgets.dart`
Expected: No errors

---

## Task 4: Pass songName through WorkoutTimerLayout

**Files:**
- Modify: `lib/widgets/workout_timer_layout.dart`

**Interfaces:**
- Consumes: `songName` from workout timer page
- Produces: passes it through to `ActionControls`

- [ ] **Step 1: Add songName parameter**

In `WorkoutTimerLayout`, add:

```dart
this.songName,

// Field:
final String? songName;
```

- [ ] **Step 2: Pass songName to ActionControls**

In the `build()` method, update the `ActionControls` call:

```dart
ActionControls(
  running: isRunning,
  complete: isComplete,
  onStartPause: onStartPause,
  onReset: onReset,
  onSkip: onSkip,
  onMusicToggle: onMusicToggle ?? () {},
  isMusicPlaying: isMusicPlaying,
  songName: songName,
),
```

- [ ] **Step 3: Pass songName from WorkoutTimerPage**

In `workout_timer_page.dart`, add to the `WorkoutTimerLayout` call:

```dart
songName: _musicService.currentSong?.title,
```

- [ ] **Step 4: Verify compilation**

Run: `flutter analyze`
Expected: No errors across all modified files

---

## Task 5: Add music support to WorkoutBuilderPlayerPage

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`

**Interfaces:**
- Consumes: `MusicService` (new instance), `AudioEngine` (existing)
- Produces: music picker + toggle in the builder player

- [ ] **Step 1: Add MusicService import and state**

Add import at top:

```dart
import 'package:my_app/services/music_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
```

In `_WorkoutBuilderPlayerPageState`, add fields:

```dart
late MusicService _musicService;
List<SongModel> _songs = const [];
bool _loadingSongs = false;
```

- [ ] **Step 2: Initialize MusicService in initState**

Update `initState()` to include `MusicService`:

```dart
@override
void initState() {
  super.initState();
  _musicService = MusicService();
  _audioEngine = AudioEngine(
    voice: GeminiVoiceService(),
    sfx: SfxService(),
    music: _musicService,
  );
  _initializeCueSettings();
}
```

- [ ] **Step 3: Dispose MusicService**

Update `dispose()`:

```dart
@override
void dispose() {
  _ticker?.cancel();
  _audioEngine.dispose();
  _musicService.dispose();
  super.dispose();
}
```

- [ ] **Step 4: Add _openMusicPicker and _toggleMusic methods**

Copy the same `_openMusicPicker()` and `_toggleMusic()` methods from Task 2 into this state class.

- [ ] **Step 5: Add music toggle button to _ControlBar**

In `_ControlBar` (line 936), add music parameters:

```dart
const _ControlBar({
  // ... existing params ...
  required this.onMusicToggle,
  required this.isMusicPlaying,
  required this.songName,
});

final VoidCallback onMusicToggle;
final bool isMusicPlaying;
final String? songName;
```

Add a music toggle button after the Skip/Reset row (after line 1040):

```dart
const SizedBox(height: 12),
SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: onMusicToggle,
    style: OutlinedButton.styleFrom(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      foregroundColor: isMusicPlaying
          ? const Color(0xFFFF8A1E)
          : Colors.white70,
      backgroundColor: isMusicPlaying
          ? const Color(0xFFFF8A1E).withValues(alpha: 0.1)
          : Colors.white.withValues(alpha: 0.06),
      side: BorderSide(
        color: isMusicPlaying
            ? const Color(0xFFFF8A1E).withValues(alpha: 0.3)
            : Colors.white.withValues(alpha: 0.12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
    ),
    icon: Icon(
      isMusicPlaying ? Icons.stop_rounded : Icons.music_off_rounded,
      size: 20,
    ),
    label: Text(
      isMusicPlaying
          ? (songName != null ? 'Stop  ${songName!}' : 'Music Playing')
          : 'Play Music',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
  ),
),
```

- [ ] **Step 6: Update _ControlBar call sites**

Find where `_ControlBar` is constructed in the build method and add:

```dart
ControlBar(
  // ... existing params ...
  onMusicToggle: _toggleMusic,
  isMusicPlaying: _musicService.player.playing,
  songName: _musicService.currentSong?.title,
),
```

- [ ] **Step 7: Add MusicChip to builder player header**

In the header `Row` (around line 532-565), add a `_MusicChip` after the settings button, similar to Task 1 Step 3.

- [ ] **Step 8: Verify compilation**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: No errors

---

## Task 6: Final verification

- [ ] **Step 1: Run full analysis**

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Test on device**

Run: `flutter run -d windows`

Verify:
1. Timer page: Music chip appears in header, tapping it opens song picker
2. Timer page: Selecting a song starts playback, music icon changes to stop icon with track name
3. Timer page: Tapping stop icon stops music
4. Builder player: Music chip appears in header, same behavior as timer
5. Builder player: Music toggle button works in control bar

- [ ] **Step 3: Commit**

```bash
git add lib/widgets/workout_timer_layout.dart lib/widgets/workout_player_widgets.dart lib/pages/workout_timer_page.dart lib/pages/workout_builder_player_page.dart
git commit -m "feat: restore music picker and toggle in timer and builder player"
```
