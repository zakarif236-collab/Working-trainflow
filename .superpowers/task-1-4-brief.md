# Task 1+4: Add music parameters to WorkoutTimerLayout and pass through to ActionControls

## Files to Modify

- `lib/widgets/workout_timer_layout.dart`

## What to Do

### Step 1: Add music-related parameters to WorkoutTimerLayout

Add these **optional** parameters to the constructor and fields to the class:

```dart
// In constructor, after the existing `canPop` parameter:
this.onMusicToggle,
this.isMusicPlaying = false,
this.selectedSongTitle,
this.loadingSongs = false,
this.onMusicPickerTap,
this.songName,

// Fields:
final VoidCallback? onMusicToggle;
final bool isMusicPlaying;
final String? selectedSongTitle;
final bool loadingSongs;
final VoidCallback? onMusicPickerTap;
final String? songName;
```

### Step 2: Update the ActionControls call in build()

Find the `ActionControls` widget call (around line 150-158). Replace the hardcoded `onMusicToggle: () {}` and `isMusicPlaying: false` with:

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

### Step 3: Add MusicChip to the header Row

In the header `Row` (around line 79-138), add the music chip AFTER the `Expanded` widget for title/subtitle and BEFORE the closing `]` of the Row's children:

```dart
if (onMusicPickerTap != null)
  _MusicChip(
    loading: loadingSongs,
    onTap: onMusicPickerTap!,
    selectedSongTitle: selectedSongTitle,
  ),
```

### Step 4: Add _MusicChip widget

Add this widget class at the bottom of `workout_timer_layout.dart`:

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

## Important Notes

- All new parameters are **optional** (with defaults) so existing callers don't break
- The `ActionControls` widget in `workout_player_widgets.dart` needs a `songName` parameter added - but do NOT modify that file in this task. Another task handles it. For now, just pass `songName` to ActionControls even though the parameter doesn't exist yet - the code won't compile until Task 3 adds it.
- Actually, wait - since it won't compile, just add the `songName` parameter to ActionControls yourself as part of this task. It's a simple one-line addition:
  - In `lib/widgets/workout_player_widgets.dart`, in the `ActionControls` class constructor, add `this.songName,` after the existing `isMusicPlaying` parameter
  - Add the field: `final String? songName;`
  - In the music button label, change the text logic to show track name when playing:
    ```dart
    label: Text(
      isMusicPlaying
          ? (songName != null ? 'Stop  ${songName!}' : 'Music Playing')
          : 'Play Music',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      ...
    ),
    ```
  - Also change the icon when playing from `Icons.music_note_rounded` to `Icons.stop_rounded`

## Context

This is a Flutter workout timer app. The `MusicService` already exists and works. During a widget refactoring, the music picker UI was removed and the toggle was wired to a no-op. We're restoring it. The existing design uses dark theme with `Color(0xFFFF8A1E)` accent, rounded corners, `Colors.white.withValues(alpha: 0.06)` backgrounds.
