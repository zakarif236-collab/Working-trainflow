# Design: AdMob New Account Rewarded Production ID Swap

Date: 2026-08-15

## Objective

Switch the app's rewarded ads to the production ad unit of the new AdMob
account (`ca-app-pub-3222893031015336`), completing the account migration
(banner → interstitial → rewarded). The SDK is already integrated and the
rewarded ad flow (`workout_builder_page.dart`) already works; only the
production rewarded ad unit IDs point at the old account and need swapping.

## Decisions (confirmed by user)

- **Rewarded unit ID:** `ca-app-pub-3222893031015336/4804623122`, used for
  **both** Android and iOS production rewarded ads (mirrors the banner and
  interstitial swaps).
- **App ID unchanged:** stays `ca-app-pub-3222893031015336~9049517717`.
  The new unit's publisher matches the App ID, so rewarded ads will fill.

## Scope

- Production (`kReleaseMode`) rewarded IDs only.
- Debug/profile builds keep Google test IDs:
  - Android rewarded: `ca-app-pub-3940256099942544/5224354917`
  - iOS rewarded: `ca-app-pub-3940256099942544/2178118514`
- No changes to App ID, banner IDs, interstitial IDs, `AndroidManifest.xml`,
  `Info.plist`, or `workout_builder_page.dart` (the load/show flow is already
  correct and consumes `AdHelper.rewardedAdUnitId`).

## Changes

### `lib/add/ad_helper.dart` (lines ~76-82)

Replace the two production rewarded ternaries so production returns the new
unit for both platforms:

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

### `test/ad_helper_test.dart` (lines ~58-67)

Update the two production rewarded expectations to
`ca-app-pub-3222893031015336/4804623122`. Debug expectations unchanged.

## Verification

- `flutter analyze` reports no new issues in changed files.
- `flutter test test/ad_helper_test.dart` passes (all 3 tests).
- Release APK builds successfully (`flutter build apk --release`).
- Device smoke test of rewarded fill pending (physical device required;
  not possible in this environment).

## Out of Scope

- Rewarded ad-loading behavior, frequency, and reward logic in
  `workout_builder_page.dart`.
- AdMob policy compliance review (user responsibility, per AdMob guide).
