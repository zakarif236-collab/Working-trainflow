import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WorkoutSessionEntry entry(int millis) => WorkoutSessionEntry(
        completedAt: DateTime.fromMillisecondsSinceEpoch(millis),
        durationSeconds: 30,
        sets: 4,
        workSeconds: 240,
        restSeconds: 180,
        intensity: WorkoutIntensity.medium,
      );

  WorkoutInsights insightsAt(DateTime? lastWorkoutAt, {required int total}) =>
      WorkoutInsights(
        displayName: 'Test',
        profileImagePath: '',
        bio: '',
        totalWorkouts: total,
        totalSeconds: 0,
        currentStreakDays: 0,
        bestStreakDays: 0,
        lastWorkoutAt: lastWorkoutAt,
      );

  test('builds map keyed by completedAt millis, sorted newest first', () {
    final map = sessionsToFirestoreMap([
      entry(1000),
      entry(3000),
      entry(2000),
    ]);

    expect(map.keys.toList(), ['3000', '2000', '1000']);
    expect(map['2000']!['durationSeconds'], 30);
  });

  test('trims to the newest 30 sessions', () {
    final sessions = List.generate(35, (i) => entry(1000 + i));

    final map = sessionsToFirestoreMap(sessions);

    expect(map.length, 30);
    expect(map.keys.first, '1034');
    expect(map.keys.last, '1005');
  });

  test('syncWorkoutProgressToFirestore is a no-op without Firebase', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.syncWorkoutProgressToFirestore();
    // Must not throw even though Firebase Auth is unavailable in this test.
  });

  test('recordWorkoutCompletion records locally and tolerates sync failure',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.recordWorkoutCompletion(
      600,
      when: DateTime(2026, 8, 3, 10),
    );

    final insights = await settings.loadInsights();
    expect(insights.totalWorkouts, 1);
    expect(insights.totalSeconds, 600);

    final sessions = await settings.loadRecentSessions(limit: 30);
    expect(sessions.length, 1);
    expect(sessions.first.durationSeconds, 600);
  });

  test('buildWorkoutSyncData includes stats and dotted session keys', () {
    final data = buildWorkoutSyncData(
      insightsAt(DateTime(2026, 8, 3), total: 7),
      [entry(1000)],
    );

    expect(data['totalWorkouts'], 7);
    expect(data['recentSessions.1000'], isNotNull);
    expect(data.keys.any((k) => k.startsWith('recentSessions.')), isTrue);
    expect(data.containsKey('updatedAt'), isFalse);
    expect(data.containsKey('displayName'), isFalse);
  });

  test('pickNewerInsights prefers the source with the newer last workout',
      () {
    final local = insightsAt(DateTime(2026, 8, 3), total: 5);
    final olderRemote = insightsAt(DateTime(2026, 8, 2), total: 4);
    expect(pickNewerInsights(local, olderRemote), same(local));

    final newerRemote = insightsAt(DateTime(2026, 8, 4), total: 6);
    expect(pickNewerInsights(local, newerRemote), same(newerRemote));
  });

  test('pickNewerInsights falls back to local when remote is null or empty',
      () {
    final local = insightsAt(DateTime(2026, 8, 3), total: 5);
    expect(pickNewerInsights(local, null), same(local));
    expect(pickNewerInsights(local, insightsAt(null, total: 0)), same(local));
  });

  test('pickNewerInsights uses remote on a fresh device with no local workouts',
      () {
    final emptyLocal = insightsAt(null, total: 0);
    final remote = insightsAt(DateTime(2026, 8, 3), total: 4);
    expect(pickNewerInsights(emptyLocal, remote), same(remote));
  });
}
