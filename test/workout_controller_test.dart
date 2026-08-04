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
