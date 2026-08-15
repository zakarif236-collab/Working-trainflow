### Task 3: Update tests to assert new production banner IDs

**Files:**
- Modify: `test/ad_helper_test.dart:39-47`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor` from Task 2 — same signature `(AdPlatform, AdType, {required bool production})`.
- Produces: regression coverage locking the new production banner IDs and the unchanged test IDs.

- [ ] **Step 1: Update the production banner assertions**

Edit `test/ad_helper_test.dart` lines 39-47. Change only the two banner expectations in the `production: true` test:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.banner,
            production: true),
        'ca-app-pub-3222893031015336/8843106337',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.banner, production: true),
        'ca-app-pub-3222893031015336/8843106337',
      );
```

Leave every other assertion in the file (test-ID assertions, interstitial, rewarded, unsupported-platform) unchanged.

- [ ] **Step 2: Run the ad helper tests**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/ad_helper_test.dart
git commit -m "test(ads): assert new production banner ad unit IDs"
```

---
