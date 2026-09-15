import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/pages/workout_builder_player_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    // Quiet the platform channels the player touches in a test environment.
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      const MethodChannel('wakelock_plus/method'),
      (call) async => true,
    );
    messenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => null,
    );
  });

  WorkoutBuilderExercise reps({
    String name = 'Bench Press',
    int sets = 3,
    int reps = 12,
    int restSeconds = 20,
  }) =>
      WorkoutBuilderExercise(
        name: name,
        type: WorkoutExerciseType.reps,
        sets: sets,
        reps: reps,
        workSeconds: 40,
        restSeconds: restSeconds,
      );

  WorkoutBuilderExercise timed({
    String name = 'Plank',
    int workSeconds = 20,
    int restSeconds = 10,
  }) =>
      WorkoutBuilderExercise(
        name: name,
        type: WorkoutExerciseType.time,
        sets: 1,
        workSeconds: workSeconds,
        restSeconds: restSeconds,
      );

  WorkoutBuilderRoutine routine(
    List<WorkoutBuilderExercise> exercises, {
    String name = 'Chest Workout',
  }) =>
      WorkoutBuilderRoutine(
        id: 'test-$name',
        name: name,
        createdAt: DateTime(2026),
        exercises: exercises,
      );

  Future<void> pumpPlayer(WidgetTester tester, WorkoutBuilderRoutine r) async {
    await tester.binding.setSurfaceSize(const Size(430, 1200));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: Center(
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkoutBuilderPlayerPage(),
                        settings: RouteSettings(arguments: r),
                      ),
                    );
                  },
                  child: const Text('Launch workout'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Launch workout'));
    await tester.pumpAndSettle();
  }

  Future<void> tapButton(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await tester.pump();
  }

  Future<void> startWorkout(WidgetTester tester) async {
    await tapButton(tester, 'Start');
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('single-set rep exercise shows set panel and completes',
      (tester) async {
    await pumpPlayer(tester, routine([reps(sets: 1, reps: 10, restSeconds: 0)]));

    expect(find.text('SET 1/1'), findsOneWidget);
    expect(find.text('TARGET 10 REPS'), findsOneWidget);
    expect(find.text('SET 1/1 COMPLETE'), findsOneWidget);
    expect(find.text('REPS'), findsOneWidget);

    await tapButton(tester, 'SET 1/1 COMPLETE');
    await tester.pumpAndSettle();

    expect(find.text('Workout Complete'), findsOneWidget);
  });

  testWidgets('multi-set rep exercise rests between sets and completes',
      (tester) async {
    await pumpPlayer(
      tester,
      routine([reps(sets: 3, reps: 12, restSeconds: 10)]),
    );
    await startWorkout(tester);

    expect(find.text('SET 1/3'), findsOneWidget);
    expect(find.text('TARGET 12 REPS'), findsOneWidget);

    await tapButton(tester, 'SET 1/3 COMPLETE');
    // Set 1 done -> rest before set 2.
    expect(find.text('REST'), findsOneWidget);

    await tapButton(tester, 'Skip');
    expect(find.text('SET 2/3'), findsOneWidget);

    await tapButton(tester, 'SET 2/3 COMPLETE');
    expect(find.text('REST'), findsOneWidget);

    await tapButton(tester, 'Skip');
    expect(find.text('SET 3/3'), findsOneWidget);

    // Final set completes the workout straight away (no trailing rest).
    await tapButton(tester, 'SET 3/3 COMPLETE');
    await tester.pumpAndSettle();

    expect(find.text('Workout Complete'), findsOneWidget);
  });

  testWidgets('transition from rep-based to timed exercise', (tester) async {
    await pumpPlayer(
      tester,
      routine([
        reps(name: 'Bench Press', sets: 2, reps: 10, restSeconds: 10),
        timed(name: 'Plank', workSeconds: 20, restSeconds: 10),
      ]),
    );
    await startWorkout(tester);

    expect(find.text('SET 1/2'), findsOneWidget);

    await tapButton(tester, 'SET 1/2 COMPLETE');
    expect(find.text('REST'), findsOneWidget);

    await tapButton(tester, 'Skip');
    expect(find.text('SET 2/2'), findsOneWidget);

    // Completing the final rep set moves straight into the timed exercise.
    await tapButton(tester, 'SET 2/2 COMPLETE');

    expect(find.text('Exercise: Plank'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.textContaining('COMPLETE'), findsNothing);

    await tapButton(tester, 'Skip');
    expect(find.text('REST'), findsOneWidget);
    await tapButton(tester, 'Skip');
    await tester.pumpAndSettle();
    expect(find.text('Workout Complete'), findsOneWidget);
  });

  testWidgets('transition from timed to rep-based exercise', (tester) async {
    await pumpPlayer(
      tester,
      routine([
        timed(name: 'Plank', workSeconds: 20, restSeconds: 10),
        reps(name: 'Push-ups', sets: 2, reps: 15, restSeconds: 10),
      ]),
    );
    await startWorkout(tester);

    expect(find.text('Exercise: Plank'), findsOneWidget);
    expect(find.text('WORK'), findsOneWidget);
    expect(find.textContaining('COMPLETE'), findsNothing);

    await tapButton(tester, 'Skip');
    expect(find.text('REST'), findsOneWidget);
    await tapButton(tester, 'Skip');

    expect(find.text('SET 1/2'), findsOneWidget);
    expect(find.text('TARGET 15 REPS'), findsOneWidget);

    await tapButton(tester, 'SET 1/2 COMPLETE');
    expect(find.text('REST'), findsOneWidget);
    await tapButton(tester, 'Skip');
    expect(find.text('SET 2/2'), findsOneWidget);
    await tapButton(tester, 'SET 2/2 COMPLETE');
    await tester.pumpAndSettle();
    expect(find.text('Workout Complete'), findsOneWidget);
  });

  testWidgets('timed-only routine still renders a countdown, not set buttons',
      (tester) async {
    await pumpPlayer(
      tester,
      routine([timed(name: 'Plank', workSeconds: 40, restSeconds: 20)]),
    );

    expect(find.text('WORK'), findsOneWidget);
    expect(find.text('40 seconds left'), findsOneWidget);
    expect(find.textContaining('COMPLETE'), findsNothing);
    expect(find.textContaining('TARGET'), findsNothing);
  });

  testWidgets('related GIF asset is matched by exercise name keywords',
      (tester) async {
    await pumpPlayer(
      tester,
      routine([reps(name: 'Bench Press', sets: 2, reps: 12, restSeconds: 10)]),
    );

    // The bundled bench_press.gif should be resolved and rendered in the
    // exercise hero for the "Bench Press" exercise.
    await tester.pumpAndSettle();
    final imageFinder = find.byWidgetPredicate(
      (w) =>
          w is Image &&
          (w.image is AssetImage &&
              (w.image as AssetImage).assetName.endsWith('bench_press.gif')),
    );
    expect(imageFinder, findsOneWidget);
  });
}