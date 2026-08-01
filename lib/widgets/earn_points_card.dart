import 'package:flutter/material.dart';

class EarnPointsCard extends StatelessWidget {
  const EarnPointsCard({
    super.key,
    required this.buildPoints,
    required this.todayWatches,
    required this.maxDailyWatches,
    required this.onWatchAd,
  });

  final int buildPoints;
  final int todayWatches;
  final int maxDailyWatches;
  final VoidCallback? onWatchAd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Earn Points',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            buildPoints == 1 ? '1 build point' : '$buildPoints build points',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$todayWatches/$maxDailyWatches today',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onWatchAd,
              icon: const Icon(Icons.play_circle_outline),
              label: const Text('Watch Ad (+1)'),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Watch ads to earn build points, used when you save a new workout.',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}
