# Task 2: Wire up music in WorkoutTimerPage

## Files to Modify

- `lib/pages/workout_timer_page.dart`

## What to Do

### Step 1: Add imports

At the top of the file, add:

```dart
import 'package:on_audio_query/on_audio_query.dart';
```

(Check if `SongModel` is already available via existing imports from `music_service.dart` - if MusicService exports it, this import may not be needed.)

### Step 2: Add music state variables

After the existing state variables (around line 104, after `_hasStarted`), add:

```dart
List<SongModel> _songs = const [];
bool _loadingSongs = false;
```

### Step 3: Add _openMusicPicker method

Add this method to the `_WorkoutTimerPageState` class. Place it after `_initializeFromSavedSettings()` or any other helper methods. This is copied from the old Working- version with minor updates:

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

### Step 4: Add _toggleMusic method

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

### Step 5: Update the WorkoutTimerLayout call

In `_buildWorkoutLayout()` (around line 1213), add the music parameters to the `WorkoutTimerLayout` constructor. The current call looks like:

```dart
return WorkoutTimerLayout(
  phase: phase,
  palette: palette,
  // ... existing params ...
);
```

Add these parameters at the end:

```dart
  onMusicToggle: _toggleMusic,
  isMusicPlaying: _musicService.player.playing,
  selectedSongTitle: _musicService.currentSong?.title,
  loadingSongs: _loadingSongs,
  onMusicPickerTap: _openMusicPicker,
  songName: _musicService.currentSong?.title,
```

## Context

- `MusicService` is already instantiated at line 111: `_musicService = MusicService()`
- `MusicService` has: `initialize()`, `loadSongs()`, `playSong(SongModel)`, `togglePlayPause()`, `currentSong` (getter returning `SongModel?`), `player` (AudioPlayer with `.playing` getter)
- `MusicServiceException` is the error type thrown by MusicService methods
- The old Working- version at `Working-/lib/pages/workout_timer_page.dart:234-347` has the reference implementation
- Design: dark theme, `Color(0xFF111826)` for bottom sheet, `Color(0xFF2AB7CA)` for selected song indicator

## Important

- Do NOT create a new MusicService instance - reuse the existing `_musicService` at line 111
- Do NOT modify the MusicService class itself
- The `_openMusicPicker` and `_toggleMusic` methods are new additions to the state class
