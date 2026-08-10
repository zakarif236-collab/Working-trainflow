import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

CommunityWorkout _communityWorkout({
  String id = 'cw_1',
  String title = 'Community Burner',
}) {
  return CommunityWorkout(
    id: id,
    creatorId: 'creator_1',
    creatorUsername: 'coach',
    creatorAvatarPath: '',
    title: title,
    description: 'A community workout',
    category: 'HIIT',
    difficulty: WorkoutDifficulty.beginner,
    tags: const ['Full Body'],
    coverImagePath: '',
    exercises: const [
      WorkoutBuilderExercise(name: 'Jumping Jacks', workSeconds: 30, restSeconds: 15),
      WorkoutBuilderExercise(name: 'Push Ups', workSeconds: 40, restSeconds: 20),
    ],
    createdAt: DateTime(2026, 8, 1),
    downloads: 0,
    likes: 0,
    favorites: 0,
    shares: 0,
    ratingsCount: 0,
    ratingsTotal: 0,
    isLiked: false,
    isFavorited: false,
    isSaved: false,
    comments: const [],
    isFollowingCreator: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('saving a community workout persists it into My Workouts', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.saveCommunityWorkoutToMyWorkouts(_communityWorkout());

    final routines = await settings.loadWorkoutBuilderRoutines();
    expect(routines.length, 1);
    expect(routines.first.id, 'cw_1');
    expect(routines.first.name, 'Community Burner');
    expect(routines.first.exercises.length, 2);
    expect(routines.first.exercises.first.name, 'Jumping Jacks');
    expect(routines.first.exercises.first.workSeconds, 30);
  });

  test('saving the same community workout again does not duplicate it', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.saveCommunityWorkoutToMyWorkouts(_communityWorkout());
    await settings.saveCommunityWorkoutToMyWorkouts(_communityWorkout());

    final routines = await settings.loadWorkoutBuilderRoutines();
    expect(routines.length, 1);
  });

  test('unsaving a community workout removes it from My Workouts', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.saveCommunityWorkoutToMyWorkouts(_communityWorkout());
    await settings.removeCommunityWorkoutFromMyWorkouts('cw_1');

    final routines = await settings.loadWorkoutBuilderRoutines();
    expect(routines, isEmpty);
  });

  test('unsaving an unsaved workout is a safe no-op', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.removeCommunityWorkoutFromMyWorkouts('does_not_exist');

    final routines = await settings.loadWorkoutBuilderRoutines();
    expect(routines, isEmpty);
  });
}
