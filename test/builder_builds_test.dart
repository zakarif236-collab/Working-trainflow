import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('missing builds key must not grant a free build after the initial grant',
      () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    // New user gets exactly one free build, persisted to storage.
    expect(await settings.loadBuilderBuildsRemaining(), 1);

    // User consumes the free build.
    expect(await settings.consumeBuilderBuild(), 0);

    // The counter key goes missing (simulates a restart / data-loss condition).
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('builder.buildsRemaining');

    // Regression: a missing key must NOT silently restore a free build.
    expect(await settings.loadBuilderBuildsRemaining(), 0);
  });

  test('existing counter is preserved when the app is upgraded', () async {
    SharedPreferences.setMockInitialValues({
      'builder.buildsRemaining': 0,
    });
    final settings = SettingsService();

    // A pre-existing count of 0 from an earlier install must stay 0.
    expect(await settings.loadBuilderBuildsRemaining(), 0);
  });
}
