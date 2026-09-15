# Design — Folder-Limited Music Playback

**Date:** 2026-09-15
**Status:** Approved (user)

## Problem

The music player scans the entire Android media library via `on_audio_query`'s
`querySongs()` (`lib/services/music_service.dart`). The user wants playback to be
limited to a single user-chosen folder (e.g. "Music Appel") instead. Only that
folder's supported audio files should appear in the picker.

## Decisions (from brainstorming)

- Replace the whole-device scan entirely (folder-only; no "full library" option).
- Include audio from sub-folders of the chosen folder (recursive).
- Remember the chosen folder across app launches (SharedPreferences).
- Empty / unindexed folder → user-visible message + "re-pick folder" action.
- Allowed file types: `.mp3`, `.wav`, `.aac` only (case-insensitive), plus
  MediaStore's existing `isMusic` flag and a non-empty URI check.
- Approach: **system folder picker + MediaStore path filter** (no new native
  code; no SAF tree walking).

## Approach

1. Use `file_picker.getDirectoryPath()` to open the Android system folder picker
   (SAF `ACTION_OPEN_DOCUMENT_TREE` under the hood). On Android it returns the
   chosen folder's real path (e.g. `/storage/emulated/0/Music Appel`).
2. Feed that path into `on_audio_query`'s existing `querySongs(path: ...)`,
   which applies `MediaStore.Audio.Media.DATA LIKE '%<path>/%'`, so only audio
   under that folder (including sub-folders) is returned. MediaStore does the
   scan; no manual file listing, no new native code.
3. Filter the result to `.mp3/.wav/.aac` + `isMusic` + non-empty URI.
4. Playback, title/artist metadata, and the existing bottom-sheet list UI are
   unchanged (content URIs, `just_audio`).
5. Persist the folder path and display name in SharedPreferences; auto-reload
   the folder on next launch. The sheet exposes a "Change folder" control.

Failure modes: folder picker cancelled → silent no-op; no supported audio →
friendly message with "Choose different folder" action; SDK-level unresolved
path → message asking for an internal-storage folder.

## Components

### 1. Dependency — `pubspec.yaml`

- Add `file_picker` (latest compatible, ~8.x) to `dependencies`.

### 2. `lib/services/music_service.dart`

- Add:
  ```dart
  static const _kAllowedAudioExtensions = {'.mp3', '.wav', '.aac'};
  bool isAllowedAudioExtension(String uri) // public, testable, case-insensitive
  ```
- Replace `loadSongs()` with:
  ```dart
  Future<List<SongModel>> loadSongsFromFolder(String folderPath) async
  ```
  - Empty `folderPath` → `MusicServiceException('Choose a music folder first')`.
  - Query `_query.querySongs(path: folderPath, sortType: DISPLAY_NAME, orderType: ASC_OR_SMALLER, uriType: EXTERNAL)`.
  - Filter: `song.isMusic == true`, non-empty `song.uri`, `isAllowedAudioExtension`.
  - Empty result → `MusicServiceException('No .mp3, .wav, or .aac files found in that folder.')`.
  - Re-use existing `_playlist` / `_playlistIndex` wiring (preserve current song index if still present).
  - Wrap unexpected errors identically to today (`'Unable to read your music library right now: $e'`).
- `initialize()` (permission request) is unchanged.
- Remove `loadSongs()` — no remaining call sites after this change.

### 3. New `lib/services/music_folder_prefs.dart`

- SharedPreferences keys: `music.folderPath` (String), `music.folderName` (String).
- API:
  - `Future<String?> loadFolderPath()`
  - `Future<String?> loadFolderName()`
  - `Future<void> saveFolder(String path)` — stores path + basename of `path` as the display name.
  - `Future<void> clearFolder()`

### 4. New `lib/widgets/music_folder_picker.dart`

- `Future<bool> pickAndStoreFolder(BuildContext context)`:
  - `final path = await FilePicker.platform.getDirectoryPath();`
  - `null` → cancelled → return `false` (no-op; cached folder untouched).
  - Otherwise `await MusicFolderPrefs().saveFolder(path)` → return `true`.
- `MusicFolderHeader` widget: shows `Folder: <name>` and a "Change folder"
  button that re-runs the picker and refreshes the song list via a supplied
  callback. Used at the top of the song sheet.

### 5. Player pages — `lib/pages/workout_timer_page.dart`, `lib/pages/workout_builder_player_page.dart`

Replace both duplicated `_openMusicPicker()` bodies with:

1. `await _musicService.initialize();` (existing permission gate)
2. `var folderPath = await MusicFolderPrefs().loadFolderPath();`
   - If `null`, `if (!await pickAndStoreFolder(context)) return;` then reload path.
3. `final songs = await _musicService.loadSongsFromFolder(folderPath);`
4. `setState(() => _songs = songs);`
5. Open the existing bottom-sheet list UI. Sheet subtitle becomes
   `Tracks from <folderName>`, and the sheet includes `MusicFolderHeader`.
6. The "Change folder" button re-runs the picker and re-calls steps 3–5.

Error handling (both pages):
- `MusicServiceException` → snackbar with `e.message`; for the "No ... files found"
  case, the snackbar gains a `Choose different folder` action that re-runs the picker.
- Cancelled picker → no message, no clearing of the cached folder.
- SDK-level unresolved path → handled inside `saveFolder`/picker caller with
  `'That folder cannot be read. Pick a folder on internal storage.'` (message text).

## Testing

- `test/music_folder_prefs_test.dart` — save/load basename, clear, roundtrip
  (via `SharedPreferences.setMockInitialValues`).
- `test/music_folder_filter_test.dart` — `isAllowedAudioExtension` unit tests:
  `.mp3/.wav/.aac` allowed (upper/lowercase), `.m4a/.flac/.txt`, empty/null rejected.
- Re-run `flutter analyze` — no new issues in changed files.
- Re-run existing audio/music tests; full-suite baseline unchanged (3 known
  `test/widget_test.dart` pending-timer failures are pre-existing, unrelated).

## Out of Scope

- SAF tree access fallback for unindexed folders (Approach B) — not now.
- Playback of formats beyond `.mp3/.wav/.aac`.
- iOS support (current behavior already Android-only).