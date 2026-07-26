import 'package:flutter/material.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/pages/workout_timer_page.dart';

class HomeTimerPage extends StatelessWidget {
  const HomeTimerPage({super.key, this.pendingConfig});

  final WorkoutConfig? pendingConfig;

  @override
  Widget build(BuildContext context) {
    return WorkoutTimerPage(
      launchConfig: pendingConfig,
      timerMode: TimerMode.home,
    );
  }
}