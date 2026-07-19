import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';

class GlowBlob extends StatelessWidget {
  const GlowBlob({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: 300,
        height: 300,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: 0.9),
              color.withValues(alpha: 0.3),
              color.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.45, 1.0],
          ),
        ),
      ),
    );
  }
}

class NextPhaseCard extends StatelessWidget {
  const NextPhaseCard({super.key, required this.phase});

  final WorkoutPhase phase;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.local_fire_department_rounded,
              color: Color(0xFFFFB15C),
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Up Next',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  phase.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${phase.durationSeconds}s${phase.setNumber == null ? '' : ' | Set ${phase.setNumber}'}',
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
}

class ProgressHeader extends StatelessWidget {
  const ProgressHeader({
    super.key,
    required this.progress,
    required this.elapsed,
    required this.total,
  });

  final double progress;
  final int elapsed;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Icon(Icons.bar_chart_rounded, color: Color(0xFFFF8A1E), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Workout Progress',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF8A1E).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    color: Color(0xFFFFB15C),
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A1E)),
              backgroundColor: Colors.white12,
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '${formatSeconds(elapsed)} / ${formatSeconds(total)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String formatSeconds(int value) {
    final m = value ~/ 60;
    final s = value % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

class ActionControls extends StatelessWidget {
  const ActionControls({
    super.key,
    required this.running,
    required this.complete,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
    required this.onMusicToggle,
    required this.isMusicPlaying,
  });

  final bool running;
  final bool complete;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final VoidCallback onMusicToggle;
  final bool isMusicPlaying;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ControlButton(
                label: running ? 'Pause' : complete ? 'Restart' : 'Start',
                icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                primary: true,
                onPressed: onStartPause,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ControlButton(
                label: 'Skip',
                icon: Icons.skip_next_rounded,
                primary: false,
                onPressed: onSkip,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ControlButton(
                label: 'Reset',
                icon: Icons.replay_rounded,
                primary: false,
                onPressed: onReset,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ControlButton(
                label: isMusicPlaying ? 'Pause Music' : 'Play Music',
                icon: isMusicPlaying
                    ? Icons.music_off_rounded
                    : Icons.music_note_rounded,
                primary: false,
                onPressed: onMusicToggle,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class ControlButton extends StatelessWidget {
  const ControlButton({
    super.key,
    required this.label,
    required this.icon,
    required this.primary,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool primary;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      child: primary
          ? Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF8A1E), Color(0xFFFF6B1E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF8A1E).withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: FilledButton.icon(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                icon: Icon(icon),
                label: Text(label),
              ),
            )
          : OutlinedButton.icon(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                foregroundColor: Colors.white,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              icon: Icon(icon),
              label: Text(label),
            ),
    );
  }
}

class PhaseBadge extends StatelessWidget {
  const PhaseBadge({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 16),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
