import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/workout_foreground_service.dart';

void main() {
  group('effectiveRemainingSeconds', () {
    const t0 = 1_700_000_000_000;

    test('returns remainingAtBase when the base timestamp is unset', () {
      expect(
        WorkoutForegroundService.effectiveRemainingSeconds(
          remainingAtBase: 60,
          baseAtMillis: 0,
          nowMillis: t0,
        ),
        60,
      );
    });

    test('returns full remaining when now equals the base timestamp', () {
      expect(
        WorkoutForegroundService.effectiveRemainingSeconds(
          remainingAtBase: 60,
          baseAtMillis: t0,
          nowMillis: t0,
        ),
        60,
      );
    });

    test('decrements remaining by the elapsed seconds', () {
      expect(
        WorkoutForegroundService.effectiveRemainingSeconds(
          remainingAtBase: 60,
          baseAtMillis: t0,
          nowMillis: t0 + 45_000,
        ),
        15,
      );
    });

    test('clamps at zero once elapsed exceeds remaining', () {
      expect(
        WorkoutForegroundService.effectiveRemainingSeconds(
          remainingAtBase: 60,
          baseAtMillis: t0,
          nowMillis: t0 + 120_000,
        ),
        0,
      );
    });

    test('stays accurate when reposted later (stale remaining in service)', () {
      final effective = WorkoutForegroundService.effectiveRemainingSeconds(
        remainingAtBase: 90,
        baseAtMillis: t0,
        nowMillis: t0 + 37_000,
      );
      expect(effective, 53);
    });
  });
}