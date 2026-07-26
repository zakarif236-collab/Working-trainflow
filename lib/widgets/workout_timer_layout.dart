import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/widgets/countdown_bar.dart';
import 'package:my_app/widgets/exercise_media_panel.dart';
import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/workout_timeline.dart';
import 'package:video_player/video_player.dart';

class WorkoutTimerLayout extends StatelessWidget {
  const WorkoutTimerLayout({
    super.key,
    required this.phase,
    required this.palette,
    required this.isRunning,
    required this.isComplete,
    required this.phaseProgress,
    required this.remainingSeconds,
    required this.totalProgress,
    required this.elapsedSeconds,
    required this.totalWorkoutSeconds,
    required this.timeline,
    required this.phaseIndex,
    required this.currentRemainingSeconds,
    required this.nextPhase,
    required this.mediaPath,
    required this.videoController,
    required this.loadingMedia,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
    required this.headerTitle,
    required this.headerSubtitle,
    required this.onBackPressed,
    required this.canPop,
    this.isPaused = false,
    this.onResume,
    this.onRestart,
    this.onQuit,
    this.onMusicToggle,
    this.isMusicPlaying = false,
    this.selectedSongTitle,
    this.loadingSongs = false,
    this.onMusicPickerTap,
    this.songName,
  });

  final WorkoutPhase phase;
  final List<Color> palette;
  final bool isRunning;
  final bool isComplete;
  final double phaseProgress;
  final int remainingSeconds;
  final double totalProgress;
  final int elapsedSeconds;
  final int totalWorkoutSeconds;
  final List<WorkoutPhase> timeline;
  final int phaseIndex;
  final int currentRemainingSeconds;
  final WorkoutPhase nextPhase;
  final String? mediaPath;
  final VideoPlayerController? videoController;
  final bool loadingMedia;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final String headerTitle;
  final String headerSubtitle;
  final VoidCallback onBackPressed;
  final bool canPop;
  final bool isPaused;
  final VoidCallback? onResume;
  final VoidCallback? onRestart;
  final VoidCallback? onQuit;
  final VoidCallback? onMusicToggle;
  final bool isMusicPlaying;
  final String? selectedSongTitle;
  final bool loadingSongs;
  final VoidCallback? onMusicPickerTap;
  final String? songName;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final mediaHeight = screenHeight * 0.45;
    final accentColor = palette.first;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (canPop)
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    onPressed: onBackPressed,
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              if (canPop) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      headerTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      headerSubtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.54),
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (onMusicPickerTap != null)
                _MusicChip(
                  loading: loadingSongs,
                  onTap: onMusicPickerTap!,
                  selectedSongTitle: selectedSongTitle,
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              _buildExerciseHero(context, mediaHeight, accentColor),
              const SizedBox(height: 16),
              _buildExerciseInfo(accentColor),
              const SizedBox(height: 12),
              _buildUpNextCard(),
              const SizedBox(height: 12),
              ActionControls(
                running: isRunning,
                complete: isComplete,
                onStartPause: onStartPause,
                onReset: onReset,
                onSkip: onSkip,
                onMusicToggle: onMusicToggle ?? () {},
                isMusicPlaying: isMusicPlaying,
                songName: songName,
              ),
              const SizedBox(height: 12),
              ProgressHeader(
                progress: totalProgress,
                elapsed: elapsedSeconds,
                total: totalWorkoutSeconds,
              ),
              const SizedBox(height: 12),
              WorkoutTimeline(
                timeline: timeline,
                currentIndex: phaseIndex,
                currentRemainingSeconds: currentRemainingSeconds,
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
        if (isPaused) _buildPauseOverlay(),
      ],
    );
  }

  Widget _buildExerciseHero(
    BuildContext context,
    double mediaHeight,
    Color accentColor,
  ) {
    final hasMedia = mediaPath != null && mediaPath!.trim().isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: mediaHeight,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasMedia)
              ExerciseMediaPanel(
                mediaPath: mediaPath,
                videoController: videoController,
                loading: loadingMedia,
                height: mediaHeight,
              )
            else
              _buildGradientBackground(accentColor),
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black45, Colors.black87],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: PhaseBadge(
                icon: phase.type == WorkoutPhaseType.rest
                    ? Icons.pause_rounded
                    : Icons.fitness_center_rounded,
                label: phase.type == WorkoutPhaseType.rest ? 'REST' : 'WORK',
                accent: accentColor,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildProgressBar(accentColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color accentColor) {
    final elapsed = totalWorkoutSeconds - (totalWorkoutSeconds * (1 - totalProgress)).round();
    final total = totalWorkoutSeconds;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: CountdownBar(
        progress: phaseProgress,
        seconds: remainingSeconds,
        phaseLabel: phase.label,
        gradient: palette,
        elapsedSeconds: elapsed,
        totalSeconds: total,
      ),
    );
  }

  Widget _buildExerciseInfo(Color accentColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                phase.label,
                style: TextStyle(
                  color: accentColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${phase.durationSeconds}s',
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildUpNextCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.skip_next_rounded,
              color: Color(0xFFFFB15C),
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  nextPhase.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${nextPhase.durationSeconds} sec',
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBackground(Color accentColor) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [palette[0], const Color(0xFF0D121C), palette[1]],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.self_improvement_rounded,
          color: Colors.white.withValues(alpha: 0.15),
          size: 64,
        ),
      ),
    );
  }

  Widget _buildPauseOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Text(
                'PAUSED',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _PauseButton(
              icon: Icons.play_arrow_rounded,
              label: 'Resume',
              onTap: onResume ?? () {},
              isPrimary: true,
            ),
            const SizedBox(height: 12),
            _PauseButton(
              icon: Icons.replay_rounded,
              label: 'Restart',
              onTap: onRestart ?? () {},
              isPrimary: false,
            ),
            const SizedBox(height: 12),
            _PauseButton(
              icon: Icons.stop_rounded,
              label: 'Quit',
              onTap: onQuit ?? () {},
              isPrimary: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFFFF8A1E), Color(0xFFFF6B1E)],
                )
              : null,
          color: isPrimary ? null : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary
                ? const Color(0xFFFF8A1E).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MusicChip extends StatelessWidget {
  const _MusicChip({
    required this.loading,
    required this.onTap,
    required this.selectedSongTitle,
  });

  final bool loading;
  final VoidCallback onTap;
  final String? selectedSongTitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.library_music_rounded, color: Colors.white70),
            const SizedBox(width: 8),
            Text(
              selectedSongTitle == null ? 'Music' : 'Track set',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
