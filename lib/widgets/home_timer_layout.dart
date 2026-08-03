import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/widgets/circular_countdown.dart';
import 'package:my_app/widgets/workout_player_widgets.dart';
import 'package:my_app/widgets/header_banner_ad.dart';
import 'package:my_app/widgets/workout_timeline.dart';

class HomeTimerLayout extends StatelessWidget {
  const HomeTimerLayout({
    super.key,
    required this.phase,
    required this.palette,
    required this.isRunning,
    required this.phaseProgress,
    required this.remainingSeconds,
    required this.pulseScale,
    required this.totalProgress,
    required this.elapsedSeconds,
    required this.totalWorkoutSeconds,
    required this.timeline,
    required this.phaseIndex,
    required this.currentRemainingSeconds,
    required this.nextPhase,
    required this.config,
    required this.onStartPause,
    required this.onReset,
    required this.onSkip,
    required this.headerSubtitle,
    required this.onBackPressed,
    required this.canPop,
    required this.customizationWidget,
    required this.configPanelWidget,
    required this.showCustomizationPanel,
    required this.tempoPanelWidget,
    required this.guideCards,
    this.musicControls,
  });

  final WorkoutPhase phase;
  final List<Color> palette;
  final bool isRunning;
  final double phaseProgress;
  final int remainingSeconds;
  final double pulseScale;
  final double totalProgress;
  final int elapsedSeconds;
  final int totalWorkoutSeconds;
  final List<WorkoutPhase> timeline;
  final int phaseIndex;
  final int currentRemainingSeconds;
  final WorkoutPhase nextPhase;
  final WorkoutConfig config;
  final VoidCallback onStartPause;
  final VoidCallback onReset;
  final VoidCallback onSkip;
  final String headerSubtitle;
  final VoidCallback onBackPressed;
  final bool canPop;
  final Widget customizationWidget;
  final Widget configPanelWidget;
  final bool showCustomizationPanel;
  final Widget? tempoPanelWidget;
  final List<Widget> guideCards;
  final Widget? musicControls;

  @override
  Widget build(BuildContext context) {
    final setIndicator = _buildSetIndicator();

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
                    tooltip: 'Back to Home',
                  ),
                ),
              if (canPop) const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Immersive Workout Timer',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const HeaderBannerAd(),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            children: [
              customizationWidget,
              const SizedBox(height: 10),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 220),
                crossFadeState: showCustomizationPanel
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: configPanelWidget,
              ),
              const SizedBox(height: 20),
              Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.65,
                  child: CircularCountdown(
                    progress: phaseProgress,
                    seconds: remainingSeconds,
                    phaseLabel: phase.label,
                    gradient: palette,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              if (setIndicator != null) ...[
                Center(child: setIndicator),
                const SizedBox(height: 16),
              ],
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bar_chart_rounded,
                        color: palette.first,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${(totalProgress * 100).round()}% complete',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: Text(
                          '${_formatTime(totalWorkoutSeconds - elapsedSeconds)} remaining',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              ActionControls(
                running: isRunning,
                complete: phase.type == WorkoutPhaseType.complete,
                onStartPause: onStartPause,
                onReset: onReset,
                onSkip: onSkip,
              ),
              if (musicControls != null) ...[
                const SizedBox(height: 12),
                musicControls!,
              ],
              const SizedBox(height: 12),
              NextPhaseCard(phase: nextPhase),
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
                program: config.program,
              ),
              if (tempoPanelWidget != null) ...[
                const SizedBox(height: 12),
                tempoPanelWidget!,
              ],
              ...guideCards,
              const SizedBox(height: 20),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _buildSetIndicator() {
    final currentSet = phase.setNumber;
    final totalSets = config.sets;
    if (currentSet == null || totalSets <= 0) return null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: palette.first.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.first.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.fitness_center_rounded,
            color: palette.first,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Set $currentSet of $totalSets',
            style: TextStyle(
              color: palette.first,
              fontWeight: FontWeight.w800,
              fontSize: 15,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
