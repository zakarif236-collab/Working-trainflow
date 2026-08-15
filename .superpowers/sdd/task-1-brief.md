# Task 1: Swap production interstitial IDs

**Files:**
- Modify: `lib/add/ad_helper.dart:69-74`
- Modify: `test/ad_helper_test.dart:48-57`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor(AdPlatform, AdType, {required bool production})` — returns `String`.
- Produces: No new interfaces. `AdHelper.interstitialAdUnitId` now resolves to the new production unit in release builds.

## Step 1: Update the production interstitial expectations in the test

In `test/ad_helper_test.dart`, replace the two production interstitial expectations (currently lines 48-57) so they assert the new unit ID:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.interstitial,
            production: true),
        'ca-app-pub-3222893031015336/1741873338',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.interstitial,
            production: true),
        'ca-app-pub-3222893031015336/1741873338',
      );
```

## Step 2: Run the test to verify it fails

Run: `flutter test test/ad_helper_test.dart`
Expected: the `uses production IDs when production is true` test FAILS — Android interstitial expectation got `ca-app-pub-3940256099942544/1033173712` but expected `ca-app-pub-3222893031015336/1741873338`.

## Step 3: Update the interstitial cases in `ad_helper.dart`

Replace the two `TODO(ads)` interstitial cases (currently lines 69-74) with:

```dart
      case (AdPlatform.android, AdType.interstitial):
        return production
            ? 'ca-app-pub-3222893031015336/1741873338'
            : 'ca-app-pub-3940256099942544/1033173712';
      case (AdPlatform.ios, AdType.interstitial):
        return production
            ? 'ca-app-pub-3222893031015336/1741873338'
            : 'ca-app-pub-3940256099942544/4411468910';
```

## Step 4: Run the test to verify it passes

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS (all 3 tests).

## Step 5: Run analyzer

Run: `flutter analyze`
Expected: no new issues in `lib/add/ad_helper.dart` or `test/ad_helper_test.dart`.

## Step 6: Commit

```bash
git add lib/add/ad_helper.dart test/ad_helper_test.dart
git commit -m "feat(ads): use new production interstitial ad unit IDs"
```
