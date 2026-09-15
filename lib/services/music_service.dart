import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';

class MusicService {
  MusicService()
      : _query = OnAudioQuery(),
        _player = AudioPlayer();

  final OnAudioQuery _query;
  final AudioPlayer _player;

  SongModel? _currentSong;
  double _playbackSpeed = 1.0;
  final double _normalVolume = 1.0;
  double _duckedVolume = 0.3;
  bool _isDucked = false;
  List<SongModel> _playlist = const [];
  int _playlistIndex = -1;

  final ValueNotifier<bool> playingNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<SongModel?> songNotifier = ValueNotifier<SongModel?>(null);

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

  SongModel? get currentSong => _currentSong;
  AudioPlayer get player => _player;
  double get playbackSpeed => _playbackSpeed;
  bool get hasNext => _playlist.isNotEmpty && _playlistIndex < _playlist.length - 1;
  bool get hasPrevious => _playlist.isNotEmpty && _playlistIndex > 0;
  bool get isDucked => _isDucked;

  Future<void> initialize() async {
    if (!Platform.isAndroid) {
      throw const MusicServiceException(
        'Music library browsing is currently supported on Android in this build.',
      );
    }

    final granted = await _query.permissionsStatus();
    if (!granted) {
      final requested = await _query.permissionsRequest();
      if (!requested) {
        throw const MusicServiceException(
          'Music permission denied. Enable media access in settings to use your tracks.',
        );
      }
    }
  }

  Future<List<SongModel>> loadSongs() async {
    try {
      final songs = await _query.querySongs(
        sortType: SongSortType.DISPLAY_NAME,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
      );

      final playable = songs.where((song) {
        final uri = song.uri;
        return uri != null && uri.isNotEmpty && song.isMusic == true;
      }).toList();

      if (playable.isEmpty) {
        throw const MusicServiceException(
          'No playable songs found on your device yet.',
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

  Future<void> playSong(SongModel song) async {
    final uri = song.uri;
    if (uri == null || uri.isEmpty) {
      throw const MusicServiceException(
        'That track cannot be played because its file path is unavailable.',
      );
    }

    try {
      await _player.setAudioSource(AudioSource.uri(Uri.parse(uri)));
      _playbackSpeed = 1.0;
      await _player.setSpeed(_playbackSpeed);
      await _player.play();
      playingNotifier.value = true;
      _currentSong = song;
      songNotifier.value = song;
      _playlistIndex = _playlist.indexWhere((s) => s.id == song.id);
    } catch (e) {
      throw MusicServiceException('Playback failed: $e');
    }
  }

  Future<void> next() async {
    if (_playlist.isEmpty || _playlistIndex >= _playlist.length - 1) {
      return;
    }
    _playlistIndex++;
    await playSong(_playlist[_playlistIndex]);
  }

  Future<void> previous() async {
    if (_playlist.isEmpty || _playlistIndex <= 0) {
      return;
    }
    _playlistIndex--;
    await playSong(_playlist[_playlistIndex]);
  }

  Future<void> setPlaybackSpeed(double speed) async {
    if (_currentSong == null) {
      throw const MusicServiceException(
        'Pick a song first so phase music profiles can be applied.',
      );
    }

    final next = speed.clamp(0.6, 1.4);
    try {
      await _player.setSpeed(next);
      _playbackSpeed = next;
    } catch (e) {
      throw MusicServiceException('Unable to apply music profile speed: $e');
    }
  }

  Future<void> togglePlayPause() async {
    if (_player.playing) {
      await _player.pause();
      playingNotifier.value = false;
      return;
    }

    if (_currentSong == null) {
      throw const MusicServiceException(
        'Pick a song first so we can start playback.',
      );
    }

    await _player.play();
    playingNotifier.value = true;
  }

  Future<void> stop() async {
    await _player.stop();
    _playbackSpeed = 1.0;
    _currentSong = null;
    songNotifier.value = null;
    playingNotifier.value = false;
    _playlistIndex = -1;
    _isDucked = false;
  }

  Future<void> duck() async {
    if (!_player.playing || _isDucked) {
      return;
    }
    _isDucked = true;
    try {
      await _player.setVolume(_duckedVolume);
    } catch (_) {
      // Best effort
    }
  }

  Future<void> unduck() async {
    if (!_isDucked) {
      return;
    }
    _isDucked = false;
    try {
      await _player.setVolume(_normalVolume);
    } catch (_) {
      // Best effort
    }
  }

  void setDuckedVolume(double volume) {
    _duckedVolume = volume.clamp(0.1, 0.5);
  }

  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (_) {}
  }

  Future<void> dispose() async {
    playingNotifier.dispose();
    songNotifier.dispose();
    await _player.dispose();
  }
}

class MusicServiceException implements Exception {
  const MusicServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
