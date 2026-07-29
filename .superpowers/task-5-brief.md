# Task 5: Add music support to WorkoutBuilderPlayerPage

## Files to Modify

- `lib/pages/workout_builder_player_page.dart`

## What to Do

### Step 1: Add imports

At the top of the file, add:

```dart
import 'package:my_app/services/music_service.dart';
import 'package:on_audio_query/on_audio_query.dart';
```

### Step 2: Add MusicService and music state fields

In `_WorkoutBuilderPlayerPageState`, add these fields after the existing fields (around line 61):

```dart
late MusicService _musicService;
List<SongModel> _songs = const [];
bool _loadingSongs = false;
```

### Step 3: Initialize MusicService in initState

Update `initState()` to create and use `MusicService`. The current code (lines 64-71) is:

```dart
@override
void initState() {
  super.initState();
  _audioEngine = AudioEngine(
    voice: GeminiVoiceService(),
    sfx: SfxService(),
  );
  _initializeCueSettings();
}
```

Change to:

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

### Step 4: Dispose MusicService

Find the `dispose()` method. The current code is:

```dart
@override
void dispose() {
  _ticker?.cancel();
  _audioEngine.dispose();
  super.dispose();
}
```

Change to:

```dart
@override
void dispose() {
  _ticker?.cancel();
  _audioEngine.dispose();
  _musicService.dispose();
  super.dispose();
}
```

### Step 5: Add _openMusicPicker and _toggleMusic methods

Add these methods to the state class (same as Task 2, after other helper methods):

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

### Step 6: Add music toggle to _ControlBar

The `_ControlBar` widget (around line 936) currently takes: running, complete, palette, onStartPause, onReset, onSkip.

Add these parameters:

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

### Step 7: Add music button to _ControlBar build()

In the `_ControlBar.build()` method, after the Skip/Reset row (after line 1040), add:

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

### Step 8: Update _ControlBar call sites

Find where `_ControlBar` is constructed in the build method (search for `_ControlBar(`) and add the music parameters:

```dart
_ControlBar(
  // ... existing params ...
  onMusicToggle: _toggleMusic,
  isMusicPlaying: _musicService.player.playing,
  songName: _musicService.currentSong?.title,
),
```

### Step 9: Add MusicChip to builder player header

In the header Row (around line 532-565), after the settings button and before the `SizedBox(width: 8)`, add a music chip. First, add the `_MusicChip` widget class at the bottom of the file (same as in workout_timer_layout.dart):

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

Then in the header Row, add the chip. Find the header Row and add after the last IconButton (settings gear):

```dart
const SizedBox(width: 8),
_MusicChip(
  loading: _loadingSongs,
  onTap: _openMusicPicker,
  selectedSongTitle: _musicService.currentSong?.title,
),
```

## Context

- This page currently has NO music support - only AudioEngine for voice/sfx
- `MusicService` class: `initialize()`, `loadSongs()`, `playSong(SongModel)`, `togglePlayPause()`, `currentSong` (SongModel?), `player` (AudioPlayer), `dispose()`
- `MusicServiceException` is the error type
- The `AudioEngine` constructor accepts an optional `music` parameter (line 48-55 of audio_engine.dart)
- Design: dark theme, `Color(0xFFFF8A1E)` accent, `Color(0xFF111826)` bottom sheet, `Color(0xFF2AB7CA)` selected indicator

## Important

- Do NOT create a new AudioEngine - reuse the existing `_audioEngine` at line 44
- Pass `_musicService` to `AudioEngine` constructor via the `music:` parameter
- The `_ControlBar` is a private widget defined in the same file - modify it directly
