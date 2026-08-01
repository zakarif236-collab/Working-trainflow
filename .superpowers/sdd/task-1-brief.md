### Task 1: `SettingsService` — daily ad-watch persistence

**Files:**
- Modify: `lib/services/settings_service.dart` (add two methods after `addBuilderBuilds` ~line 168; add `_dateKey` helper near `_epochDay` ~line 949; add the `_kBuilderAdWatches` key constant near line 1059)
- Test: `test/builder_ad_watches_test.dart` (new)

**Interfaces:**
- Produces:
  - `Future<int> loadAdWatchCountForToday({DateTime? now})` — returns the count of rewarded ads watched today (0 when nothing stored, when the stored date is stale, or on corrupt JSON).
  - `Future<void> recordAdWatchForToday({DateTime? now})` — increments today's count in storage.
  - The optional `now` param enables deterministic tests, matching the existing `shouldSendMissedWorkoutReminder({DateTime? now})` pattern. Callers use the default (`DateTime.now()`).
  - Consumed by Task 3 (`_loadAdWatchCountForToday`, `_watchAdForPoint`).

- [ ] **Step 1: Write the failing test**

Create `test/builder_ad_watches_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/builder_ad_watches_test.dart`
Expected: FAIL — compile error "The method 'loadAdWatchCountForToday' isn't defined for the type 'SettingsService'".

- [ ] **Step 3: Write minimal implementation**

In `lib/services/settings_service.dart`, insert right after the `addBuilderBuilds` method (which ends at line 168):

```dart
  Future<int> loadAdWatchCountForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_kBuilderAdWatches);
    if (encoded == null || encoded.trim().isEmpty) {
      return 0;
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return 0;
      }

      if (decoded['date'] != _dateKey(now ?? DateTime.now())) {
        return 0;
      }

      return (decoded['count'] as num?)?.toInt() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> recordAdWatchForToday({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await loadAdWatchCountForToday(now: now);
    await prefs.setString(
      _kBuilderAdWatches,
      jsonEncode({'date': _dateKey(now ?? DateTime.now()), 'count': current + 1}),
    );
  }
```

Near `_epochDay` (line 949), add the date-key helper:

```dart
  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
```

In the key-constant block near line 1059, add after `_kBuilderBuildsInitialized`:

```dart
const _kBuilderAdWatches = 'builder.adWatches';
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/builder_ad_watches_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/services/settings_service.dart test/builder_ad_watches_test.dart
git commit -m "feat: track daily rewarded ad watches in settings service"
```

---

