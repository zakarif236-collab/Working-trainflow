import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const regenDuration = Duration(days: 2);

  test('no spend never regenerates a build even after 2 days', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 1,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final now = DateTime(2026, 8, 12, 12);

    expect(
      await settings.loadBuilderBuildsRemaining(now: now.add(regenDuration)),
      1,
    );
  });

  test('regenerates exactly one build 2 days after a spend', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 0,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final spendTime = DateTime(2026, 8, 10, 12);

    await settings.consumeBuilderBuild(now: spendTime);

    expect(
      await settings.loadBuilderBuildsRemaining(now: spendTime),
      0,
    );
    expect(
      await settings.loadBuilderBuildsRemaining(now: spendTime.add(regenDuration)),
      1,
    );
  });

  test('a regenerated build is not granted twice from the same spend', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 0,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final spendTime = DateTime(2026, 8, 10, 12);

    await settings.consumeBuilderBuild(now: spendTime);

    final afterTwoDays = spendTime.add(regenDuration);
    expect(await settings.loadBuilderBuildsRemaining(now: afterTwoDays), 1);
    expect(await settings.loadBuilderBuildsRemaining(now: afterTwoDays), 1);
  });

  test('a fresh spend after regeneration arms the timer again', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 1,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final firstSpend = DateTime(2026, 8, 10, 12);

    await settings.consumeBuilderBuild(now: firstSpend);
    final afterFirstRegen = firstSpend.add(regenDuration);
    expect(await settings.loadBuilderBuildsRemaining(now: afterFirstRegen), 1);

    // Spend again; only after another 2 days does the next regen land.
    final secondSpend = afterFirstRegen.add(const Duration(hours: 1));
    await settings.consumeBuilderBuild(now: secondSpend);
    expect(
      await settings.loadBuilderBuildsRemaining(now: secondSpend.add(const Duration(days: 1))),
      0,
    );
    expect(
      await settings.loadBuilderBuildsRemaining(now: secondSpend.add(regenDuration)),
      1,
    );
  });

  test('regeneration is skipped while disabled', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 0,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final spendTime = DateTime(2026, 8, 10, 12);

    await settings.consumeBuilderBuild(now: spendTime);

    expect(
      await settings.loadBuilderBuildsRemaining(
        now: spendTime.add(regenDuration),
        regenerationEnabled: false,
      ),
      0,
    );
  });

  test('maybeRegenerateBuilderBuild reports whether a grant happened', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 0,
      'builder.buildsInitialized': true,
    });
    final settings = SettingsService();
    final spendTime = DateTime(2026, 8, 10, 12);

    await settings.consumeBuilderBuild(now: spendTime);

    expect(
      await settings.maybeRegenerateBuilderBuild(now: spendTime),
      false,
    );
    expect(
      await settings.maybeRegenerateBuilderBuild(now: spendTime.add(regenDuration)),
      true,
    );
    expect(
      await settings.maybeRegenerateBuilderBuild(now: spendTime.add(regenDuration)),
      false,
    );
  });
}
