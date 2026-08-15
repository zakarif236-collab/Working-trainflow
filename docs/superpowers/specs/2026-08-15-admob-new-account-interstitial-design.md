# Design: AdMob New Account Interstitial Production ID Swap

Date: 2026-08-15

## Objective

Switch the app's interstitial ads to the production ad unit of the new AdMob
account (`ca-app-pub-3222893031015336`), following the same pattern used for the
recent banner swap. This is the follow-up: interstitials now point at real
inventory.

## Decisions (confirmed by user)

- **Interstitial unit ID:** `ca-app-pub-3222893031015336/1741873338`, used for
  **both** Android and iOS production interstitials (mirrors how the banner unit
  was applied).
- **App ID unchanged.** The App ID stays `ca-app-pub-3222893031015336~9049517717`
  (already in `AndroidManifest.xml` and `Info.plist`). A supplied alternate value
  with publisher `...3031615336` was rejected as a likely typo; its publisher
  would not match the interstitial (or banner) units.

## Scope

- Production (`kReleaseMode`) interstitial IDs only.
- Debug/profile builds keep Google test IDs:
  - Android interstitial: `ca-app-pub-3940256099942544/1033173712`
  - iOS interstitial: `ca-app-pub-3940256099942544/4411468910`
- No changes to App ID, banner IDs, rewarded IDs, `AndroidManifest.xml`, or
  `Info.plist`.

## Changes

### `lib/add/ad_helper.dart` (lines ~69-74)

Replace the two `TODO(ads)` interstitial cases so production returns the new unit
for both platforms:

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

### `test/ad_helper_test.dart` (lines ~48-57)

Update the two production interstitial expectations to
`ca-app-pub-3222893031015336/1741873338`. Debug expectations unchanged.

## Verification

- `flutter analyze` reports no new issues in changed files.
- `flutter test test/ad_helper_test.dart` passes (all 3 tests).
- Release APK builds successfully (`flutter build apk --release`).

## Out of Scope

- Rewarded ads still point at the old account (`.../6138624088986178/2840036851`,
  `.../7209425656`) — known follow-up, intentional.
- Interstitial ad-loading behavior and frequency in app code.
