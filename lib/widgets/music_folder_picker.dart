import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../services/music_folder_prefs.dart';
import '../services/music_service.dart';

/// Opens the system folder picker and persists the choice. Returns true when a
/// folder is now stored. A cancelled or empty result is a no-op that leaves any
/// cached folder untouched.
Future<bool> pickAndStoreFolder() async {
  final path = await FilePicker.getDirectoryPath();
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
      final newName = await widget.prefs.loadFolderName();
      if (!mounted) {
        return;
      }
      setState(() {
        _songs = newSongs;
        _folderName = newName;
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