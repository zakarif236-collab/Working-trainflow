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

  test('trims to the newest 100 sessions', () {
    final sessions = List.generate(105, (i) => entry(1000 + i));

    final map = sessionsToFirestoreMap(sessions);

    expect(map.length, 100);
    expect(map.keys.first, '1104');
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

  test('mergeSessionsByTimestamp unions and dedups by timestamp key', () {
    final local = [entry(1000), entry(2000), entry(2000)];
    final remote = [entry(2000), entry(3000)];

    final merged = mergeSessionsByTimestamp(local, remote);

    expect(merged.length, 3);
    expect(
      merged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
      [3000, 2000, 1000],
    );
  });

  test('mergeSessionsByTimestamp caps the union', () {
    final local = List.generate(60, (i) => entry(1000 + i));
    final remote = List.generate(60, (i) => entry(1_000_000 + i));

    final merged = mergeSessionsByTimestamp(local, remote);

    expect(merged.length, 100);
    expect(merged.first.completedAt.millisecondsSinceEpoch, 1_000_059);
  });

  test('computeStreaks counts consecutive days ending at the most recent', () {
    // Days 10, 9, 8, then a gap, then 5, 4.
    final sessions = [
      entry(DateTime(2026, 8, 4).millisecondsSinceEpoch),
      entry(DateTime(2026, 8, 3).millisecondsSinceEpoch),
      entry(DateTime(2026, 8, 2).millisecondsSinceEpoch),
      entry(DateTime(2026, 7, 30).millisecondsSinceEpoch),
      entry(DateTime(2026, 7, 29).millisecondsSinceEpoch),
    ];

    final (current, best) = computeStreaks(sessions);

    expect(current, 3); // Aug 4, 3, 2
    expect(best, 3);
  });

  test('computeStreaks handles single session and empty list', () {
    final (singleCurrent, singleBest) = computeStreaks([entry(1000)]);
    expect(singleCurrent, 1);
    expect(singleBest, 1);

    final (emptyCurrent, emptyBest) = computeStreaks(const []);
    expect(emptyCurrent, 0);
    expect(emptyBest, 0);
  });

  test('resolveInsights recomputes counters from a complete union', () {
    final local = insightsAt(null, total: 2);
    final remote = insightsAt(DateTime(2026, 8, 4), total: 2);
    final union = [entry(4000), entry(3000), entry(2000), entry(1000)];

    final resolved = resolveInsights(local, remote, union);

    expect(resolved.totalWorkouts, 4);
    expect(resolved.totalSeconds, 120);
    expect(resolved.lastWorkoutAt, DateTime.fromMillisecondsSinceEpoch(4000));
    expect(resolved.displayName, 'Test'); // profile fields come from pickNewerInsights
  });

  test('resolveInsights falls back to monotonic max when truncated', () {
    final local = WorkoutInsights(
      displayName: 'Test',
      profileImagePath: '',
      bio: '',
      totalWorkouts: 150,
      totalSeconds: 9000,
      currentStreakDays: 30,
      bestStreakDays: 40,
      lastWorkoutAt: DateTime(2026, 8, 1),
    );
    final remote = WorkoutInsights(
      displayName: 'Test',
      profileImagePath: '',
      bio: '',
      totalWorkouts: 80,
      totalSeconds: 5000,
      currentStreakDays: 12,
      bestStreakDays: 20,
      lastWorkoutAt: DateTime(2026, 8, 2),
    );
    // Union is capped (length >= cap), so the list is incomplete.
    final union = List.generate(100, (i) => entry(1000 + i));

    final resolved = resolveInsights(local, remote, union);

    expect(resolved.totalWorkouts, 150); // max, never drops
    expect(resolved.totalSeconds, 9000);
    expect(resolved.currentStreakDays, 30);
    expect(resolved.bestStreakDays, 40);
    expect(resolved.lastWorkoutAt, DateTime(2026, 8, 2)); // later of the two
  });

  test('two devices offline, then converge to an identical union', () {
    // Device A's local history.
    final deviceA = [entry(1000), entry(2000)];
    // Device B's disjoint offline history.
    final deviceB = [entry(3000), entry(4000)];

    // A merges: its local sessions + the remote (B's) sessions.
    final aMerged = mergeSessionsByTimestamp(deviceA, deviceB);
    final aResolved = resolveInsights(
      insightsAt(null, total: 2),
      insightsAt(DateTime.fromMillisecondsSinceEpoch(4000), total: 2),
      aMerged,
    );

    // B merges: its local sessions + the remote (A's) sessions.
    final bMerged = mergeSessionsByTimestamp(deviceB, deviceA);
    final bResolved = resolveInsights(
      insightsAt(null, total: 2),
      insightsAt(DateTime.fromMillisecondsSinceEpoch(4000), total: 2),
      bMerged,
    );

    expect(aMerged.length, 4);
    expect(bMerged.length, 4);
    expect(aResolved.totalWorkouts, 4);
    expect(aResolved.totalSeconds, 120);
    // Both devices end up with the identical union.
    expect(
      bMerged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
      aMerged.map((s) => s.completedAt.millisecondsSinceEpoch).toList(),
    );
    expect(bResolved.totalWorkouts, aResolved.totalWorkouts);
    expect(bResolved.totalSeconds, aResolved.totalSeconds);
  });
}
