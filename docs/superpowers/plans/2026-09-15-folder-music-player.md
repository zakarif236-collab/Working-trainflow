# Folder-Limited Music Playback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Limit the workout music player to a single user-chosen folder (e.g. "Music Appel"), remembered across launches, showing only `.mp3`/`.wav`/`.aac` files from that folder (recursively).

**Architecture:** The Android system folder picker (`file_picker.getDirectoryPath()`, which wraps `ACTION_OPEN_DOCUMENT_TREE`) returns the folder's real path. `MusicService` keeps its `READ_MEDIA_AUDIO` permission flow but loads songs via `on_audio_query`'s `querySongs(path: ...)`, which applies a MediaStore `DATA LIKE '%<path>/%'` filter — so only audio under that folder returns. The choice persists in `SharedPreferences`, and a shared bottom sheet replaces the duplicated per-page picker code.

**Tech Stack:** Flutter/Dart, `file_picker` (new), `on_audio_query` (existing), `just_audio` (existing), `shared_preferences` (existing).

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-15-folder-music-player-design.md`.
- Allowed extensions (case-insensitive, lowercase set): `.mp3`, `.wav`, `.aac` only.
- Folder scans are **recursive** (sub-folders included) — this falls out of the MediaStore `%<path>/%` LIKE filter; do not add depth limits.
- Folder-only: `loadSongs()` (whole-library) must be fully removed by the final task — no "full library" option remains.
- `READ_MEDIA_AUDIO` permission flow in `MusicService.initialize()` is unchanged; no new AndroidManifest entries (SAF directory picker needs none).
- Remember the folder: SharedPreferences keys `music.folderPath` and `music.folderName` (basename).
- Cancel/empty system picker result = silent no-op (do NOT clear the cached folder).
- Follow existing code style: no new comments beyond the existing DocComment convention in `lib/services/` and `lib/widgets/`.

---

### Task 1: Music folder preference storage

**Files:**
- Create: `lib/services/music_folder_prefs.dart`
- Test: `test/music_folder_prefs_test.dart`

**Interfaces:**
- Produces: `class MusicFolderPrefs` with `Future<String?> loadFolderPath()`, `Future<String?> loadFolderName()`, `Future<void> saveFolder(String path)`, `Future<void> clearFolder()`. Used by Tasks 3–5.

- [ ] **Step 1: Write the failing test**

Create `test/music_folder_prefs_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/music_folder_prefs.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('loadFolderPath returns null when nothing was saved', () async {
    expect(await MusicFolderPrefs().loadFolderPath(), isNull);
    expect(await MusicFolderPrefs().loadFolderName(), isNull);
  });

  test('saveFolder persists the path and the basename', () async {
    await MusicFolderPrefs().saveFolder('/storage/emulated/0/Music Appel');

    expect(
      await MusicFolderPrefs().loadFolderPath(),
      '/storage/emulated/0/Music Appel',
    );
    expect(await MusicFolderPrefs().loadFolderName(), 'Music Appel');
  });

  test('saveFolder normalizes backslashes and trailing slashes', () async {
    await MusicFolderPrefs().saveFolder(r'C:\Music Appel\');

    expect(await MusicFolderPrefs().loadFolderPath(), 'C:/Music Appel/');
    expect(await MusicFolderPrefs().loadFolderName(), 'Music Appel');
  });

  test('clearFolder removes both keys', () async {
    final prefs = MusicFolderPrefs();
    await prefs.saveFolder('/storage/emulated/0/Music');
    await prefs.clearFolder();

    expect(await prefs.loadFolderPath(), isNull);
    expect(await prefs.loadFolderName(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/music_folder_prefs_test.dart`
Expected: FAIL — `Error: Dart library 'my_app' does not contain a top-level definition named 'MusicFolderPrefs'`.

- [ ] **Step 3: Write minimal implementation**

Create `lib/services/music_folder_prefs.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user-chosen music folder across app launches.
class MusicFolderPrefs {
  MusicFolderPrefs();

  static const String _folderPathKey = 'music.folderPath';
  static const String _folderNameKey = 'music.folderName';

  /// The stored folder path (e.g. `/storage/emulated/0/Music Appel`), or null
  /// when the user has not picked a folder yet.
  Future<String?> loadFolderPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderPathKey);
  }

  /// The stored display name (folder basename), or null.
  Future<String?> loadFolderName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_folderNameKey);
  }

  /// Stores [path] and its basename. The path is normalized to forward
  /// slashes so non-Android paths remain usable on other platforms.
  Future<void> saveFolder(String path) async {
    final normalized = path.replaceAll('\\', '/');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_folderPathKey, normalized);
    await prefs.setString(_folderNameKey, _basename(normalized));
  }

  /// Removes the stored folder (used by tests / future reset flows).
  Future<void> clearFolder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_folderPathKey);
    await prefs.remove(_folderNameKey);
  }

  String _basename(String path) {
    final trimmed = path.endsWith('/')
        ? path.substring(0, path.length - 1)
        : path;
    final lastSlash = trimmed.lastIndexOf('/');
    return lastSlash == -1 ? trimmed : trimmed.substring(lastSlash + 1);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/music_folder_prefs_test.dart`
Expected: PASS (`4` tests, `All tests passed!`).

- [ ] **Step 5: Commit**

```bash
git add lib/services/music_folder_prefs.dart test/music_folder_prefs_test.dart
git commit -m "feat: add music folder preference storage"
```

---

### Task 2: Folder-scoped song loading in MusicService

**Files:**
- Modify: `lib/services/music_service.dart` (add helpers + `loadSongsFromFolder`; keep `loadSongs()` for now — removed in Task 6)
- Test: `test/music_folder_filter_test.dart`

**Interfaces:**
- Consumes: `SongModel` from `package:on_audio_query/on_audio_query.dart` (already imported).
- Produces:
  - `static const Set<String> MusicService.allowedAudioExtensions` = `{'.mp3', '.wav', '.aac'}`
  - `static bool MusicService.isAllowedAudioExtension(String pathOrUri)`
  - `static bool MusicService.isPlayableFromFolder(SongModel song)`
  - `Future<List<SongModel>> MusicService.loadSongsFromFolder(String folderPath)`
  - Throws `MusicServiceException` with exactly: `'Choose a music folder first.'`, `'No .mp3, .wav, or .aac files found in that folder.'`, or `'Unable to read your music library right now: <err>'`.

- [ ] **Step 1: Write the failing test**

Create `test/music_folder_filter_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/music_service.dart';
import 'package:on_audio_query/on_audio_query.dart';

SongModel songWith(Map<String, dynamic> info) => SongModel(info);

void main() {
  group('isAllowedAudioExtension', () {
    test('allows .mp3, .wav, and .aac', () {
      expect(MusicService.isAllowedAudioExtension('/x/a.mp3'), isTrue);
      expect(MusicService.isAllowedAudioExtension('/x/a.wav'), isTrue);
      expect(MusicService.isAllowedAudioExtension('/x/a.aac'), isTrue);
    });

    test('is case-insensitive', () {
      expect(MusicService.isAllowedAudioExtension('/x/A.MP3'), isTrue);
      expect(MusicService.isAllowedAudioExtension('/x/A.Wav'), isTrue);
    });

    test('extracts the extension from the trailing dot', () {
      expect(MusicService.isAllowedAudioExtension('/x/My.Song Name.mp3'), isTrue);
    });

    test('rejects other formats', () {
      expect(MusicService.isAllowedAudioExtension('/x/a.m4a'), isFalse);
      expect(MusicService.isAllowedAudioExtension('/x/a.flac'), isFalse);
      expect(MusicService.isAllowedAudioExtension('/x/a.ogg'), isFalse);
      expect(MusicService.isAllowedAudioExtension('/x/a'), isFalse);
      expect(MusicService.isAllowedAudioExtension(''), isFalse);
    });
  });

  group('isPlayableFromFolder', () {
    test('accepts music with an allowed extension and a uri', () {
      final song = songWith({
        '_id': 1,
        '_data': '/storage/emulated/0/Music Appel/track.mp3',
        '_uri': 'content://media/external/audio/media/1',
        'title': 'track',
        'is_music': true,
      });
      expect(MusicService.isPlayableFromFolder(song), isTrue);
    });

    test('rejects non-music entries', () {
      final song = songWith({
        '_id': 2,
        '_data': '/storage/emulated/0/Music Appel/ring.mp3',
        '_uri': 'content://media/external/audio/media/2',
        'title': 'ring',
        'is_music': false,
      });
      expect(MusicService.isPlayableFromFolder(song), isFalse);
    });

    test('rejects songs without a uri', () {
      final song = songWith({
        '_id': 3,
        '_data': '/storage/emulated/0/Music Appel/track.mp3',
        '_uri': null,
        'title': 'track',
        'is_music': true,
      });
      expect(MusicService.isPlayableFromFolder(song), isFalse);
    });

    test('rejects disallowed extensions even when tagged as music', () {
      final song = songWith({
        '_id': 4,
        '_data': '/storage/emulated/0/Music Appel/track.m4a',
        '_uri': 'content://media/external/audio/media/4',
        'title': 'track',
        'is_music': true,
      });
      expect(MusicService.isPlayableFromFolder(song), isFalse);
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/music_folder_filter_test.dart`
Expected: FAIL — `The method 'isAllowedAudioExtension' isn't defined for the class 'MusicService'`.

- [ ] **Step 3: Write minimal implementation**

In `lib/services/music_service.dart`, inside `class MusicService`, immediately after the existing field declarations block (after `final ValueNotifier<SongModel?> songNotifier = ValueNotifier<SongModel?>(null);`), add:

```dart
  /// File extensions that count as playable music from the chosen folder.
  static const Set<String> allowedAudioExtensions = {'.mp3', '.wav', '.aac'};

  /// Case-insensitive check that [pathOrUri] ends with an allowed extension.
  /// Public and pure so the folder filter can be unit-tested.
  static bool isAllowedAudioExtension(String pathOrUri) {
    final dot = pathOrUri.lastIndexOf('.');
    if (dot == -1 || dot == pathOrUri.length - 1) {
      return false;
    }
    return allowedAudioExtensions.contains(pathOrUri.substring(dot).toLowerCase());
  }

  /// Whether [song] qualifies for folder-scoped playback: media access, an
  /// available uri, and an allowed file extension.
  static bool isPlayableFromFolder(SongModel song) {
    final uri = song.uri;
    if (uri == null || uri.isEmpty) {
      return false;
    }
    if (song.isMusic != true) {
      return false;
    }
    return isAllowedAudioExtension(song.data);
  }
```

Then add `loadSongsFromFolder` directly below the existing `loadSongs()` method (keeping `loadSongs()` for now — it is deleted in Task 6):

```dart
  /// Load only the music physically located under [folderPath] (including
  /// sub-folders, via the MediaStore path filter) and filtered to the allowed
  /// file extensions.
  Future<List<SongModel>> loadSongsFromFolder(String folderPath) async {
    if (folderPath.trim().isEmpty) {
      throw const MusicServiceException('Choose a music folder first.');
    }

    try {
      final songs = await _query.querySongs(
        path: folderPath,
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final playable = songs.where(isPlayableFromFolder).toList();

      if (playable.isEmpty) {
        throw const MusicServiceException(
          'No .mp3, .wav, or .aac files found in that folder.',
        );
      }

      _playlist = playable;
      if (_currentSong != null) {
        _playlistIndex = playable.indexWhere((s) => s.id == _currentSong!.id);
      }

      return playable;
    } catch (e) {
      if (e is MusicServiceException) {
        rethrow;
      }
      throw MusicServiceException(
        'Unable to read your music library right now: $e',
      );
    }
  }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/music_folder_filter_test.dart`
Expected: PASS (`9` tests, `All tests passed!`).

- [ ] **Step 5: Analyze the changed file**

Run: `flutter analyze lib/services/music_service.dart test/music_folder_filter_test.dart`
Expected: `No issues found!`

- [ ] **Step 6: Commit**

```bash
git add lib/services/music_service.dart test/music_folder_filter_test.dart
git commit -m "feat: add folder-scoped song loading to MusicService"
```

---

### Task 3: Folder picker, header, and shared song sheet

**Files:**
- Modify: `pubspec.yaml` (add `file_picker`)
- Create: `lib/widgets/music_folder_picker.dart`
- Test: `test/music_folder_picker_test.dart`

**Interfaces:**
- Consumes: `MusicFolderPrefs` (Task 1), `MusicService` / `MusicServiceException` / `loadSongsFromFolder` (Task 2), `SongModel` from `on_audio_query`.
- Produces:
  - `Future<bool> pickAndStoreFolder()` — opens the system folder picker, persists via `MusicFolderPrefs().saveFolder(path)`; returns whether a folder is now stored (false on cancel/empty).
  - `class MusicFolderHeader extends StatelessWidget` — `{required String? folderName, required VoidCallback onChangeFolder}`.
  - `Future<void> showMusicSongSheet(BuildContext context, MusicService musicService)` — permission gate → resolve folder (prompt if none) → load songs → bottom sheet; handles all `MusicServiceException`s.

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add file_picker`
Expected: `file_picker ...  has been added` / `Got dependencies!`.

- [ ] **Step 2: Write the failing widget test**

Create `test/music_folder_picker_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/widgets/music_folder_picker.dart';

void main() {
  testWidgets('header shows the folder name and fires the change callback',
      (tester) async {
    var changed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicFolderHeader(
            folderName: 'Music Appel',
            onChangeFolder: () => changed = true,
          ),
        ),
      ),
    );

    expect(find.text('Music Appel'), findsOneWidget);
    expect(find.text('Change folder'), findsOneWidget);

    await tester.tap(find.text('Change folder'));
    expect(changed, isTrue);
  });

  testWidgets('header falls back when no folder name is available',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MusicFolderHeader(folderName: null, onChangeFolder: () {}),
        ),
      ),
    );

    expect(find.text('No folder selected'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/music_folder_picker_test.dart`
Expected: FAIL — `'MusicFolderHeader' isn't defined`.

- [ ] **Step 4: Write the implementation**

Create `lib/widgets/music_folder_picker.dart` with this exact content:

```dart
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/music_folder_prefs.dart';
import '../services/music_service.dart';

/// Opens the system folder picker and persists the choice. Returns true when a
/// folder is now stored. A cancelled or empty result is a no-op that leaves any
/// cached folder untouched.
Future<bool> pickAndStoreFolder() async {
  final path = await FilePicker.platform.getDirectoryPath();
  if (path == null || path.isEmpty) {
    return false;
  }
  await MusicFolderPrefs().saveFolder(path);
  return true;
}

/// Small header shown above the song list: current folder name + the control
/// used to change folder.
class MusicFolderHeader extends StatelessWidget {
  const MusicFolderHeader({
    super.key,
    required this.folderName,
    required this.onChangeFolder,
  });

  final String? folderName;
  final VoidCallback onChangeFolder;

  @override
  Widget build(BuildContext context) {
    final label = (folderName == null || folderName!.trim().isEmpty)
        ? 'No folder selected'
        : folderName;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.folder_open_rounded, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: onChangeFolder,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFFF8A1E),
            ),
            child: const Text('Change folder', style: TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

/// Resolves the folder, loads its songs, and shows the folder-scoped picker
/// sheet. Errors surface as snackbars; a cancelled folder picker is a silent
/// no-op.
Future<void> showMusicSongSheet(
  BuildContext context,
  MusicService musicService,
) async {
  try {
    await musicService.initialize();
  } on MusicServiceException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
    return;
  }

  final prefs = MusicFolderPrefs();
  String? folderName = await prefs.loadFolderName();
  String? folderPath = await prefs.loadFolderPath();
  if (folderPath == null || folderPath.isEmpty) {
    final picked = await pickAndStoreFolder();
    if (!picked || !context.mounted) {
      return;
    }
    folderPath = await prefs.loadFolderPath();
    folderName = await prefs.loadFolderName();
  }

  List<SongModel> songs;
  try {
    songs = await musicService.loadSongsFromFolder(folderPath!);
  } on MusicServiceException catch (e) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e.message),
        action: SnackBarAction(
          label: 'Choose different folder',
          onPressed: () => showMusicSongSheet(context, musicService),
        ),
      ),
    );
    return;
  }

  if (!context.mounted) {
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF111826),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) {
      return _MusicSongSheet(
        musicService: musicService,
        prefs: prefs,
        initialSongs: songs,
        initialFolderName: folderName,
      );
    },
  );
}

class _MusicSongSheet extends StatefulWidget {
  const _MusicSongSheet({
    required this.musicService,
    required this.prefs,
    required this.initialSongs,
    this.initialFolderName,
  });

  final MusicService musicService;
  final MusicFolderPrefs prefs;
  final List<SongModel> initialSongs;
  final String? initialFolderName;

  @override
  State<_MusicSongSheet> createState() => _MusicSongSheetState();
}

class _MusicSongSheetState extends State<_MusicSongSheet> {
  late List<SongModel> _songs = widget.initialSongs;
  late String? _folderName = widget.initialFolderName;

  Future<void> _changeFolder() async {
    final picked = await pickAndStoreFolder();
    if (!picked || !mounted) {
      return;
    }
    final newPath = await widget.prefs.loadFolderPath();
    try {
      final newSongs = await widget.musicService.loadSongsFromFolder(newPath!);
      if (!mounted) {
        return;
      }
      setState(() {
        _songs = newSongs;
      });
    } on MusicServiceException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
            Text(
              (_folderName == null || _folderName!.trim().isEmpty)
                  ? 'Pick a local song'
                  : 'Tracks from $_folderName',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 12),
            MusicFolderHeader(
              folderName: _folderName,
              onChangeFolder: _changeFolder,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: _songs.length,
                separatorBuilder: (_, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  final selected =
                      widget.musicService.currentSong?.id == song.id;
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
                        await widget.musicService.playSong(song);
                        if (!context.mounted) {
                          return;
                        }
                        Navigator.pop(context);
                      } on MusicServiceException catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(e.message)),
                          );
                        }
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
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/music_folder_picker_test.dart`
Expected: PASS (`2` tests, `All tests passed!`).

- [ ] **Step 6: Analyze the new file**

Run: `flutter analyze lib/widgets/music_folder_picker.dart test/music_folder_picker_test.dart`
Expected: `No issues found!`

- [ ] **Step 7: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/widgets/music_folder_picker.dart test/music_folder_picker_test.dart
git commit -m "feat: add folder picker and folder-scoped song sheet"
```

---

### Task 4: Use folder-scoped picker in the timer page

**Files:**
- Modify: `lib/pages/workout_timer_page.dart`
  - Remove import `package:on_audio_query/on_audio_query.dart` (line 14).
  - Add import `package:my_app/widgets/music_folder_picker.dart` after the existing `music_service.dart` import.
  - Remove field `List<SongModel> _songs = const [];` (line 109).
  - Replace `_openMusicPicker()` method body (lines 824–934).

**Interfaces:**
- Consumes: `showMusicSongSheet(BuildContext, MusicService)` (Task 3). `MusicService` field `_musicService` already exists.

- [ ] **Step 1: Replace the picker method**

After the change, `_openMusicPicker()` must be exactly:

```dart
  Future<void> _openMusicPicker() async {
    await showMusicSongSheet(context, _musicService);
  }
```

Delete the old method body (the full `showModalBottomSheet` block plus its `try`/`on MusicServiceException`/`finally`).

- [ ] **Step 2: Remove the now-unused state and import**

- Delete the line `  List<SongModel> _songs = const [];`.
- Delete the import `import 'package:on_audio_query/on_audio_query.dart';`.
- Add after the line importing `music_service.dart`:
  ```dart
  import 'package:my_app/widgets/music_folder_picker.dart';
  ```

- [ ] **Step 3: Analyze the changed file**

Run: `flutter analyze lib/pages/workout_timer_page.dart`
Expected: `No issues found!` (if a pre-existing info like `avoid_print` appears it is unrelated to this task; do not fix it).

- [ ] **Step 4: Smoke-test compile + run related tests**

Run: `flutter test test/music_folder_prefs_test.dart test/music_folder_filter_test.dart test/music_folder_picker_test.dart`
Expected: PASS (9 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/pages/workout_timer_page.dart
git commit -m "refactor: use folder-scoped music picker in timer page"
```

---

### Task 5: Use folder-scoped picker in the builder player page

**Files:**
- Modify: `lib/pages/workout_builder_player_page.dart`
  - Remove import `package:on_audio_query/on_audio_query.dart` (line 17).
  - Add import `package:my_app/widgets/music_folder_picker.dart` after the existing `music_service.dart` import.
  - Remove field `List<SongModel> _songs = const [];` (line 53).
  - Replace `_openMusicPicker()` method body (lines 618–726).

**Interfaces:**
- Consumes: `showMusicSongSheet(BuildContext, MusicService)` (Task 3). `MusicService` field `_musicService` already exists.

- [ ] **Step 1: Replace the picker method**

After the change, `_openMusicPicker()` must be exactly:

```dart
  Future<void> _openMusicPicker() async {
    await showMusicSongSheet(context, _musicService);
  }
```

Delete the old method body (the full `showModalBottomSheet` block plus its `try`/`on MusicServiceException`).

- [ ] **Step 2: Remove the now-unused state and import**

- Delete the line `  List<SongModel> _songs = const [];`.
- Delete the import `import 'package:on_audio_query/on_audio_query.dart';`.
- Add after the line importing `music_service.dart`:
  ```dart
  import 'package:my_app/widgets/music_folder_picker.dart';
  ```

- [ ] **Step 3: Analyze the changed file**

Run: `flutter analyze lib/pages/workout_builder_player_page.dart`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
git add lib/pages/workout_builder_player_page.dart
git commit -m "refactor: use folder-scoped music picker in builder player page"
```

---

### Task 6: Remove the whole-library scan and run full verification

**Files:**
- Modify: `lib/services/music_service.dart` (delete `loadSongs()`)

**Interfaces:**
- Consumes: Tasks 4–5 moved all call sites off `loadSongs()`; it is now dead code.

- [ ] **Step 1: Delete the dead method**

Delete the entire `loadSongs()` method from `lib/services/music_service.dart` (the `Future<List<SongModel>> loadSongs() async { ... }` block that calls `_query.querySongs(...)` with no path). `loadSongsFromFolder` is the only public loading entry point now.

- [ ] **Step 2: Full analyze**

Run: `flutter analyze`
Expected: no **new** issues vs. the repo baseline (12 pre-existing info-level lints in unrelated files are acceptable and unchanged).

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: all tests pass except the 3 known pre-existing `test/widget_test.dart` pending-timer failures (`Calisthenics quick start opens workout page`, `VO2max quick start opens workout page`, `Workout timer is shown by default on home tab`). No **new** failures.

- [ ] **Step 4: Commit**

```bash
git add lib/services/music_service.dart
git commit -m "refactor: drop unused whole-library music scan"
```

---

## Self-Review Notes (for the implementer)

- The `file_picker` SAF directory picker returns `null` for BOTH a cancelled pick and the rare SDK read failure, so we treat `null`/empty as "cancelled, no change" (spec's separate "cannot be read" message would be unreachable — load-time query errors are already covered by the `'Unable to read your music library right now'` fallback in `loadSongsFromFolder`).
- `MusicService.isPlayableFromFolder` uses `song.data` (the file path) for the extension check, because MediaStore content URIs do not carry extensions; `song.data` is guaranteed non-null by `on_audio_query`.
- Recursive sub-folder inclusion is satisfied by the MediaStore `DATA LIKE '%<path>/%'` filter — no extra code required.
- Extension matching is case-insensitive; `.mp3/.wav/.aac` are the only allowed formats.