import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/models/workout_models.dart';
import 'package:my_app/services/settings_service.dart';

void main() {
  WorkoutSessionEntry entry(int millis) => WorkoutSessionEntry(
        completedAt: DateTime.fromMillisecondsSinceEpoch(millis),
        durationSeconds: 30,
        sets: 4,
        workSeconds: 240,
        restSeconds: 180,
        intensity: WorkoutIntensity.medium,
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
}
