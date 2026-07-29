# Task 2: Create MusicControls widget

## Status: COMPLETE

## Commit
- `a6a12cd` — feat: add MusicControls widget with play/pause/skip/stop

## What was done
- Created `lib/widgets/music_controls.dart` with `MusicControls` StatelessWidget
- Widget uses nested `ValueListenableBuilder` on `playingNotifier` and `songNotifier`
- Shows picker button when no song, or playback controls (play/pause, skip, stop) when active
- Added `on_audio_query` import for `SongModel` type (plan didn't include it)
- `flutter analyze` — 0 issues

## Report path
`C:\Users\hp\my_app\.superpowers\task-2-music-report.md`
