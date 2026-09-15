import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';

void main() {
  WorkoutBuilderExercise repsExercise({
    int sets = 3,
    int reps = 12,
    int restSeconds = 40,
    int workSeconds = 40,
  }) =>
      WorkoutBuilderExercise(
        name: 'Bench Press',
        type: WorkoutExerciseType.reps,
        sets: sets,
        reps: reps,
        workSeconds: workSeconds,
        restSeconds: restSeconds,
      );

  WorkoutBuilderExercise timeExercise({
    int sets = 1,
    int workSeconds = 40,
    int restSeconds = 20,
  }) =>
      WorkoutBuilderExercise(
        name: 'Plank',
        type: WorkoutExerciseType.time,
        sets: sets,
        workSeconds: workSeconds,
        restSeconds: restSeconds,
      );

  group('WorkoutBuilderExercise JSON', () {
    test('round-trips reps type, sets, and reps', () {
      final exercise = repsExercise(sets: 4, reps: 12, restSeconds: 40);

      final restored = WorkoutBuilderExercise.fromJson(exercise.toJson());

      expect(restored.type, WorkoutExerciseType.reps);
      expect(restored.sets, 4);
      expect(restored.reps, 12);
      expect(restored.restSeconds, 40);
      expect(restored.name, 'Bench Press');
    });

    test('legacy JSON without type/sets/reps defaults to single-set time', () {
      final legacy = WorkoutBuilderExercise.fromJson(const {
        'name': 'Plank',
        'workSeconds': 40,
        'restSeconds': 20,
        'mediaPath': '',
      });

      expect(legacy.type, WorkoutExerciseType.time);
      expect(legacy.sets, 1);
      expect(legacy.reps, 10);
      expect(legacy.workSeconds, 40);
      expect(legacy.restSeconds, 20);
    });

    test('unknown type falls back to time', () {
      final restored = WorkoutBuilderExercise.fromJson(const {
        'name': 'X',
        'type': 'bogus',
        'sets': 2,
        'reps': 8,
        'workSeconds': 30,
        'restSeconds': 15,
      });

      expect(restored.type, WorkoutExerciseType.time);
      expect(restored.sets, 2);
    });
  });

  group('WorkoutBuilderExercise estimates', () {
    test('assumedSetSeconds converts reps to seconds, clamps to a minimum', () {
      expect(repsExercise(reps: 12).assumedSetSeconds, 36);
      expect(repsExercise(reps: 1).assumedSetSeconds, 10);
      expect(timeExercise(workSeconds: 40).assumedSetSeconds, 40);
    });

    test('single-set exercise keeps its rest as a bridge to the next exercise',
        () {
      // 1 x 12 reps (36s) + 40s rest.
      expect(repsExercise(sets: 1, reps: 12, restSeconds: 40).estimatedDurationSeconds, 76);
      // Timed legacy behavior unchanged: 40s work + 20s rest.
      expect(timeExercise().estimatedDurationSeconds, 60);
    });

    test('multi-set exercise rests after every set except the last', () {
      // 4 x 12 reps: 4*36s + 3*40s rests.
      expect(repsExercise(sets: 4, reps: 12, restSeconds: 40).estimatedDurationSeconds, 264);
      // 4 x 40s work: 4*40s + 3*30s rests.
      expect(timeExercise(sets: 4, workSeconds: 40, restSeconds: 30).estimatedDurationSeconds, 250);
    });

    test('final set of a multi-set exercise has no trailing rest', () {
      // 2 x 10 reps (30s each) + 1 rest of 20s = 80s.
      final exercise = repsExercise(sets: 2, reps: 10, restSeconds: 20);
      expect(exercise.estimatedDurationSeconds, 80);
    });
  });

  group('WorkoutBuilderRoutine', () {
    test('estimatedDurationSeconds sums exercises using rep estimates', () {
      final routine = WorkoutBuilderRoutine(
        id: 'r1',
        name: 'Chest',
        createdAt: DateTime(2026),
        exercises: [
          repsExercise(sets: 4, reps: 12, restSeconds: 40), // 264
          repsExercise(sets: 3, reps: 10, restSeconds: 40), // 3*30 + 2*40 = 170
          repsExercise(sets: 3, reps: 12, restSeconds: 40), // 3*36 + 2*40 = 188
          repsExercise(sets: 3, reps: 15, restSeconds: 30), // 3*45 + 2*30 = 195
        ],
      );

      expect(routine.estimatedDurationSeconds, 264 + 170 + 188 + 195);
    });

    test('fingerprint distinguishes rep-based from time-based exercises', () {
      WorkoutBuilderRoutine routineOf(WorkoutExerciseType type) =>
          WorkoutBuilderRoutine(
            id: 'r',
            name: 'Bench',
            createdAt: DateTime(2026),
            exercises: [
              WorkoutBuilderExercise(
                name: 'Bench Press',
                type: type,
                sets: 4,
                reps: 12,
                workSeconds: 40,
                restSeconds: 40,
              ),
            ],
          );

      expect(
        routineOf(WorkoutExerciseType.reps).fingerprint,
        isNot(routineOf(WorkoutExerciseType.time).fingerprint),
      );
    });
  });
}