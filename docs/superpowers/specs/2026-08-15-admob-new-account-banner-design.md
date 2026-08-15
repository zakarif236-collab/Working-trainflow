# AdMob New Account Banner Swap — Design

**Date:** 2026-08-15
**Status:** Approved by user

## Problem

The app's AdMob integration points at the old account:

- App ID `ca-app-pub-6138624088986178~6997939566` in
  `android/app/src/main/AndroidManifest.xml` and `ios/Runner/Info.plist`.
- Production banner IDs from that old account in
  `lib/add/ad_helper.dart`.

The user has a new AdMob account with a new App ID and a new banner ad unit
ID, and wants the banner to use the new account's inventory in release builds
while keeping Google test IDs active in debug/profile builds.

## Goal

- Replace the App ID with `ca-app-pub-3222893031015336~9049517717` in both
  `AndroidManifest.xml` (as `meta-data` inside `<application>`) and
  `Info.plist` (`GADApplicationIdentifier`).
- Release builds use the new banner ad unit ID
  `ca-app-pub-3222893031015336/8843106337` on **both** Android and iOS.
- Debug/profile builds keep Google test banner IDs on both platforms.
- Interstitial and rewarded slots are **unchanged** (banner-only swap per user
  decision).

## Approach

The existing `AdHelper.adUnitIdFor(platform, type, {required bool production})`
resolver already selects IDs by compile-time `kReleaseMode`. Only the banner
production values change; the test values, interstitial slots, and rewarded
slots stay as they are.

### ID matrix (after change)

| Type        | Platform | Debug/profile (test)                 | Release (production)                 |
|-------------|----------|--------------------------------------|--------------------------------------|
| Banner      | Android  | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-3222893031015336/8843106337` |
| Banner      | iOS      | `ca-app-pub-3940256099942544/2934735716` | `ca-app-pub-3222893031015336/8843106337` |
| Interstitial| Android  | `ca-app-pub-3940256099942544/1033173712` | same (test, unchanged)              |
| Interstitial| iOS      | `ca-app-pub-3940256099942544/4411468910` | same (test, unchanged)              |
| Rewarded    | Android  | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-6138624088986178/2840036851` |
| Rewarded    | iOS      | `ca-app-pub-3940256099942544/2178118514` | `ca-app-pub-6138624088986178/7209425656` |

### App ID

- `android/app/src/main/AndroidManifest.xml`: change the `meta-data`
  `com.google.android.gms.ads.APPLICATION_ID` value to
  `ca-app-pub-3222893031015336~9049517717`.
- `ios/Runner/Info.plist`: change `GADApplicationIdentifier` to
  `ca-app-pub-3222893031015336~9049517717`.

## Files Changed

- `android/app/src/main/AndroidManifest.xml` — App ID value.
- `ios/Runner/Info.plist` — App ID value.
- `lib/add/ad_helper.dart` — banner production IDs (both platforms).
- `test/ad_helper_test.dart` — update expected production banner IDs.

## Unchanged

- Ad call sites (`header_banner_ad.dart`, `home_page.dart`,
  `workout_builder_page.dart`) — they already route through `AdHelper`.
- Interstitial and rewarded IDs and their TODOs.
- SDK initialization flow (`AdHelper.ensureInitialized` memoized future,
  gated ad loads).
- Error handling for unsupported platforms.

## Testing

- Update `test/ad_helper_test.dart` production-banner assertions to the new
  IDs; the `production: false` assertions stay on Google test IDs.
- Run `flutter test` and `flutter analyze`; both must pass.
- Verify the App ID appears exactly once in each platform config file.

## Out of Scope / Notes

- The new banner ID is used for both Android and iOS banners in release. If
  AdMob serves per-platform banner units, an iOS-specific production banner ID
  may need to be added later; flagged to the user and approved as-is.
- Rewarded production IDs still reference the old account and are left
  untouched per the approved banner-only scope.
