# Task 1: Swap production rewarded IDs

**Files:**
- Modify: `lib/add/ad_helper.dart:76-82`
- Modify: `test/ad_helper_test.dart:58-67`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor(AdPlatform, AdType, {required bool production})` — returns `String`.
- Produces: No new interfaces. `AdHelper.rewardedAdUnitId` now resolves to the new production unit in release builds. `workout_builder_page.dart` consumes it unchanged via `_loadRewardedAd` (`lib/pages/workout_builder_page.dart:107`).

## Step 1: Update the production rewarded expectations in the test

In `test/ad_helper_test.dart`, replace the two production rewarded expectations (currently lines 58-67) so they assert the new unit ID:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.rewarded,
            production: true),
        'ca-app-pub-3222893031015336/4804623122',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.rewarded,
            production: true),
        'ca-app-pub-3222893031015336/4804623122',
      );
```

## Step 2: Run the test to verify it fails

Run: `flutter test test/ad_helper_test.dart`
Expected: the `uses production IDs when production is true` test FAILS — Android rewarded expectation got `ca-app-pub-6138624088986178/2840036851` but expected `ca-app-pub-3222893031015336/4804623122`.

## Step 3: Update the rewarded cases in `ad_helper.dart`

Replace the two production rewarded ternaries (currently lines 76-82) with:

```dart
      case (AdPlatform.android, AdType.rewarded):
        return production
            ? 'ca-app-pub-3222893031015336/4804623122'
            : 'ca-app-pub-3940256099942544/5224354917';
      case (AdPlatform.ios, AdType.rewarded):
        return production
            ? 'ca-app-pub-3222893031015336/4804623122'
            : 'ca-app-pub-3940256099942544/2178118514';
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
git commit -m "feat(ads): use new production rewarded ad unit IDs"
```
