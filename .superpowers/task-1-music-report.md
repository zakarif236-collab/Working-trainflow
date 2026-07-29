# Task 1: Add reactive notifiers to MusicService

## Status: DONE

## Changes

Modified `lib/services/music_service.dart`:
- Added `import 'package:flutter/foundation.dart';` for `ValueNotifier`
- Added `playingNotifier` (`ValueNotifier<bool>`) and `songNotifier` (`ValueNotifier<SongModel?>`) fields
- Updated `playSong()` to set both notifiers on playback start
- Updated `togglePlayPause()` to sync `playingNotifier` on pause/play
- Updated `stop()` to reset both notifiers to null/false
- Updated `dispose()` to dispose both notifiers before player

## Verification

- `flutter analyze lib/services/music_service.dart` — No issues found

## Commit

`296ff23` — feat: add reactive notifiers to MusicService
