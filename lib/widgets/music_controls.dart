import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:my_app/services/music_service.dart';

class MusicControls extends StatelessWidget {
  const MusicControls({
    super.key,
    required this.musicService,
    required this.onOpenPicker,
  });

  final MusicService musicService;
  final VoidCallback onOpenPicker;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: musicService.playingNotifier,
      builder: (context, isPlaying, _) {
        return ValueListenableBuilder<SongModel?>(
          valueListenable: musicService.songNotifier,
          builder: (context, currentSong, _) {
            final hasSong = currentSong != null;

            return AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: isPlaying || hasSong
                  ? _buildPlaybackControls(context, isPlaying, currentSong)
                  : _buildPickerButton(context),
            );
          },
        );
      },
    );
  }

  Widget _buildPickerButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onOpenPicker,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          foregroundColor: Colors.white70,
          backgroundColor: Colors.white.withValues(alpha: 0.06),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: const Icon(Icons.music_note_rounded, size: 20),
        label: const Text(
          'Play Music',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls(
    BuildContext context,
    bool isPlaying,
    SongModel? song,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A1E).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFFF8A1E).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.music_note_rounded,
            color: const Color(0xFFFF8A1E),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              song?.title ?? 'Music',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          IconButton(
            onPressed: () async {
              await musicService.togglePlayPause();
            },
            icon: Icon(
              isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: Colors.white,
            ),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () async {
              await musicService.next();
            },
            icon: const Icon(Icons.skip_next_rounded, color: Colors.white),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          IconButton(
            onPressed: () async {
              await musicService.stop();
            },
            icon: const Icon(Icons.stop_rounded, color: Colors.white),
            iconSize: 22,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }
}
