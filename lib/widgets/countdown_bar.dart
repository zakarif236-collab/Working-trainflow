import 'package:flutter/material.dart';

class CountdownBar extends StatelessWidget {
  const CountdownBar({
    super.key,
    required this.progress,
    required this.seconds,
    required this.phaseLabel,
    required this.gradient,
    this.pulseScale = 1.0,
    this.elapsedSeconds,
    this.totalSeconds,
  });

  final double progress;
  final int seconds;
  final String phaseLabel;
  final List<Color> gradient;
  final double pulseScale;
  final int? elapsedSeconds;
  final int? totalSeconds;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);
    final isUrgent = seconds <= 3 && seconds > 0;

    return Transform.scale(
      scale: pulseScale,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          boxShadow: [
            if (isUrgent)
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.3 * pulseScale),
                blurRadius: 24 + (pulseScale - 1.0) * 40,
                spreadRadius: -2,
              ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    phaseLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: gradient.first,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUrgent
                        ? gradient.first.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    elapsedSeconds != null && totalSeconds != null
                        ? '${_formatTime(elapsedSeconds!)} / ${_formatTime(totalSeconds!)}'
                        : _formatTime(seconds),
                    style: TextStyle(
                      color: isUrgent ? gradient.first : Colors.white70,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: Stack(
                children: [
                  Container(
                    height: 10,
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                  FractionallySizedBox(
                    widthFactor: safeProgress,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: gradient.first.withValues(alpha: 0.5),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '${(safeProgress * 100).round()}% complete',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  seconds > 0 ? '$seconds seconds left' : 'Complete',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
