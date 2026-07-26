import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ExerciseMediaPanel extends StatelessWidget {
  const ExerciseMediaPanel({
    super.key,
    required this.mediaPath,
    required this.videoController,
    required this.loading,
    this.height,
  });

  final String? mediaPath;
  final VideoPlayerController? videoController;
  final bool loading;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: height ?? 190),
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        child: _buildMediaContent(key: mediaPath ?? 'empty'),
      ),
    );
  }

  Widget _buildMediaContent({required String key}) {
    final hasMedia = mediaPath != null;
    final isVideo =
        hasMedia && mediaPath!.startsWith('assets/exercises/videos/');

    if (loading) {
      return const Center(
        key: ValueKey('loading'),
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (!hasMedia) {
      return const Center(
        key: ValueKey('empty'),
        child: Text(
          'Add GIF/MP4 files to assets/exercises to see exercise visuals here.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    if (isVideo) {
      if (videoController != null && videoController!.value.isInitialized) {
        final ratio = videoController!.value.aspectRatio <= 0
            ? 16 / 9
            : videoController!.value.aspectRatio;
        return ClipRRect(
          key: ValueKey(key),
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: ratio,
            child: VideoPlayer(videoController!),
          ),
        );
      } else {
        return Center(
          key: ValueKey('video-loading-$key'),
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      }
    }

    return ClipRRect(
      key: ValueKey(key),
      borderRadius: BorderRadius.circular(16),
      child: Image.asset(
        mediaPath!,
        fit: BoxFit.cover,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Text(
              'Could not load this exercise image.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        },
      ),
    );
  }
}
