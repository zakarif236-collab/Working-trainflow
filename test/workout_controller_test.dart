import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/controllers/workout_controller.dart';
import 'package:my_app/models/workout_models.dart';

void main() {
  testWidgets('remainingSeconds reaches 0 before the next phase starts',
      (WidgetTester tester) async {
    final observed = <int>[];
    final controller = WorkoutController(
      initialConfig: const WorkoutConfig(
        sets: 1,
        workSeconds: 5,
        restSeconds: 5,
        warmupSeconds: 0,
        cooldownSeconds: 0,
        intensity: WorkoutIntensity.medium,
      ),
    );
    controller.addListener(() {
      observed.add(controller.remainingSeconds);
    });

    controller.start();
    observed.clear();
    await tester.pump(const Duration(seconds: 1));
    expect(observed, [4]);

    observed.clear();
    await tester.pump(const Duration(seconds: 4));

    expect(observed, contains(0));
    expect(controller.isComplete, isTrue);

    controller.dispose();
  });

  testWidgets('reconcileElapsed fast-forwards within the current phase',
      (WidgetTester tester) async {
    final controller = WorkoutController(
      initialConfig: const WorkoutConfig(
        sets: 1,
        workSeconds: 5,
        restSeconds: 5,
        warmupSeconds: 0,
        cooldownSeconds: 0,
        intensity: WorkoutIntensity.medium,
      ),
    );

    controller.start();
    expect(controller.remainingSeconds, 5);

    controller.reconcileElapsed(const Duration(seconds: 3));
    expect(controller.remainingSeconds, 2);
    expect(controller.isRunning, isTrue);

    controller.dispose();
  });

  testWidgets('reconcileElapsed advances through phases for long pauses',
      (WidgetTester tester) async {
    final controller = WorkoutController(
      initialConfig: const WorkoutConfig(
        sets: 2,
        workSeconds: 5,
        restSeconds: 5,
        warmupSeconds: 0,
        cooldownSeconds: 0,
        intensity: WorkoutIntensity.medium,
      ),
    );

    controller.start();
    expect(controller.remainingSeconds, 5);
    expect(controller.phaseIndex, 0);

    // 7s of wall-clock time: 5s work phase completes, 2s into the rest phase.
    controller.reconcileElapsed(const Duration(seconds: 7));
    expect(controller.phaseIndex, 1);
    expect(controller.remainingSeconds, 3);
    expect(controller.isRunning, isTrue);

    controller.dispose();
  });

  testWidgets('reconcileElapsed completes the workout when elapsed exceeds it',
      (WidgetTester tester) async {
    final controller = WorkoutController(
      initialConfig: const WorkoutConfig(
        sets: 1,
        workSeconds: 5,
        restSeconds: 5,
        warmupSeconds: 0,
        cooldownSeconds: 0,
        intensity: WorkoutIntensity.medium,
      ),
    );

    controller.start();
    controller.reconcileElapsed(const Duration(seconds: 60));
    expect(controller.isComplete, isTrue);
    expect(controller.isRunning, isFalse);
    expect(controller.remainingSeconds, 0);

    controller.dispose();
  });

  testWidgets('reconcileElapsed is a no-op when the timer is not running',
      (WidgetTester tester) async {
    final controller = WorkoutController(
      initialConfig: const WorkoutConfig(
        sets: 1,
        workSeconds: 5,
        restSeconds: 5,
        warmupSeconds: 0,
        cooldownSeconds: 0,
        intensity: WorkoutIntensity.medium,
      ),
    );

    controller.pause();
    controller.reconcileElapsed(const Duration(seconds: 30));
    expect(controller.remainingSeconds, 5);
    expect(controller.isComplete, isFalse);

    controller.dispose();
  });
}
