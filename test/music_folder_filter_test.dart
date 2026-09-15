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