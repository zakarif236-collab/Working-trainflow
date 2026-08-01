import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/services/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loadAdWatchCountForToday returns 0 when no data is stored', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 0);
  });

  test('loadAdWatchCountForToday returns the count for the stored day',
      () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":3}',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 3);
  });

  test('loadAdWatchCountForToday resets to 0 on a new calendar day', () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":3}',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 2)), 0);
  });

  test('loadAdWatchCountForToday falls back to 0 on corrupt JSON', () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': 'not-json{',
    });
    final settings = SettingsService();

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 0);
  });

  test('recordAdWatchForToday increments across multiple calls', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsService();

    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 1));
    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 1));

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 1)), 2);
  });

  test('recordAdWatchForToday starts a fresh count on a new calendar day',
      () async {
    SharedPreferences.setMockInitialValues({
      'builder.adWatches': '{"date":"2026-08-01","count":4}',
    });
    final settings = SettingsService();

    await settings.recordAdWatchForToday(now: DateTime(2026, 8, 2));

    expect(await settings.loadAdWatchCountForToday(now: DateTime(2026, 8, 2)), 1);
  });
}
