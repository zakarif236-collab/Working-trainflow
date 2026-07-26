import 'dart:math' as math;

import 'package:flutter/material.dart';

class CircularCountdown extends StatelessWidget {
  const CircularCountdown({
    super.key,
    required this.progress,
    required this.seconds,
    required this.phaseLabel,
    required this.gradient,
    this.subtitle,
  });

  final double progress;
  final int seconds;
  final String phaseLabel;
  final List<Color> gradient;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return AspectRatio(
      aspectRatio: 1,
      child: CustomPaint(
        painter: _CountdownPainter(
          progress: safeProgress,
          gradient: gradient,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatTime(seconds),
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      fontSize: 64,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                phaseLabel,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.orange.shade300,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ],
          ),
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

class _CountdownPainter extends CustomPainter {
  _CountdownPainter({required this.progress, required this.gradient});

  final double progress;
  final List<Color> gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * 0.44;

    final basePaint = Paint()
      ..color = Colors.white12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final arcPaint = Paint()
      ..shader = SweepGradient(
        colors: gradient,
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _CountdownPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.gradient != gradient;
  }
}
