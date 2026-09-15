# Design: Guided Music Folder Selection

Date: 2026-09-15

## Goal

Make folder selection in the music picker guided instead of a confusing raw
directory tree: suggest common folders, remember the last choice, provide helper
text, offer a fallback scan, and fail gently when a folder has no music.

## Requirements

1. Default suggestions — hint: "Most users keep songs in the Music folder."
2. Recent folder memory — auto-load last chosen folder (already implemented).
3. Guidance text — "Tip: If you're unsure, try the Music folder at the root of your storage."
4. Fallback scan — "Scan common folders" button listing candidates (Music, Downloads, DCIM/Audio), user picks from the shortlist.
5. Error handling — "No songs found here. Try picking the Music folder instead."

## Components

### lib/services/music_service.dart

- Add `static const List<String> commonSongFolderCandidates`:
  `/storage/emulated/0/Music`, `/storage/emulated/0/Download`, `/storage/emulated/0/DCIM/Audio`
- Add `static String displayNameForFolderPath(String path)` returning the
  basename (e.g. `Music`, `Download`, `Audio`).
- Add `Future<Map<String, List<SongModel>>> scanCommonSongFolders()`:
  for each candidate, run `_query.querySongs(path:)` (same sort/order/uri
  options as `loadSongsFromFolder`), filter with `isPlayableFromFolder`, and
  keep only folders with a non-empty playable list. A candidate that throws is
  skipped; other candidates still run. Returns `{path: songs}`.
- Change `loadSongsFromFolder`'s empty-folder message to:
  `'No songs found here. Try picking the Music folder instead.'`

### lib/widgets/music_folder_picker.dart

- Public enum `FolderLauncherChoice { scan, browse }` (null = dismissed).
- `Future<FolderLauncherChoice?> showGuidedChooserSheet(BuildContext context)`
  — bottom sheet titled "Where are your songs?" with the hint line "Most users
  keep songs in the Music folder.", a FilledButton "Scan common folders"
  (pops `scan`), an OutlinedButton "Browse folders" (pops `browse`).
- `Future<String?> pickFromCommonFolderScanSheet(BuildContext context, MusicService musicService, MusicFolderPrefs prefs)`
  — calls `scanCommonSongFolders()`; if empty shows "No songs found in the
  common folders. Try browsing instead." and returns null; otherwise shows a
  shortlist (title = `displayNameForFolderPath`, subtitle = full path), saves
  the tapped folder to prefs, and returns its path (null on dismiss).
- Rework `showMusicSongSheet`:
  - If no stored folder: show `showGuidedChooserSheet`; `scan` →
    `pickFromCommonFolderScanSheet`, `browse` → `pickAndStoreFolder()`.
  - Load songs for the active folder; on `MusicServiceException` show the
    friendly snackbar with action "Find songs" that reopens the guided chooser
    (recursion terminates because it is user-initiated).
  - Extract `Future<List<SongModel>?> _resolveSongs(...)` to share the
    no-folder/scan/browse/error logic between the initial open and the
    "Find songs" action. Returns null when the user gives up, else songs.
- `_MusicSongSheet`:
  - Add the muted tip line "Tip: If you're unsure, try the Music folder at the
    root of your storage." under the existing guidance (folder name line +
    "Tap Change Music Folder to pick another.").
  - Add a subtle "Scan common folders" TextButton under the header; `_scanFolders`
    runs `pickFromCommonFolderScanSheet`, then reloads songs + folder name into
    `setState` (friendly snackbar + "Pick again" on error).

## Deliberately Out of Scope

- Hard-setting the SAF start path (not possible on Android).
- Extra candidate folders beyond Music/Download/DCIM/Audio.
- Background/headless scanning.

## Testing

- `test/music_folder_filter_test.dart`: assert candidate list contents and
  `displayNameForFolderPath` outputs.
- `test/music_folder_picker_test.dart`: widget test pumping a MaterialApp —
  `showGuidedChooserSheet` renders both hint texts; tapping "Scan common
  folders" returns `FolderLauncherChoice.scan`; tapping "Browse folders"
  returns `browse`.
- Scan query and reworked `showMusicSongSheet` flow are integration-tested on a
  real device (same as existing `loadSongsFromFolder`).
- `flutter test`: 69 pass / 3 known `widget_test.dart` pending-timer failures.
  `flutter analyze`: 12 pre-existing info lints, none new.