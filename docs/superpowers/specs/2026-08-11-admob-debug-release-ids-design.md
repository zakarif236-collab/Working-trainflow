# AdMob Debug/Release Ad Unit IDs — Design

**Date:** 2026-08-11
**Status:** Approved by user

## Problem

`lib/add/ad_helper.dart` currently returns Google test ad unit IDs for Android
(banner, interstitial, rewarded) unconditionally, while iOS uses production IDs
even in debug builds. An uploaded release AAB would therefore still show only
test ads and never request live inventory. Mixing test IDs into release builds
can also flag an AdMob account.

## Goal

- Debug/profile builds use Google test ad unit IDs on both platforms.
- Release builds use production ad unit IDs for banner and rewarded on both
  platforms.
- Interstitials stay on test IDs on both platforms for now (no production
  interstitial IDs available yet) with a clear TODO to wire them in later.
- Release AAB builds automatically get production IDs with no build flag to
  remember.

## Approach

Use Flutter's compile-time `kReleaseMode` constant (from
`package:flutter/foundation.dart`) to select IDs inside `AdHelper`. The branch
is a `const`, so the unused path is tree-shaken and the selection costs nothing
at runtime.

### ID matrix

| Type        | Platform | Debug/profile (test)                 | Release (production)                 |
|-------------|----------|--------------------------------------|--------------------------------------|
| Banner      | Android  | `ca-app-pub-3940256099942544/6300978111` | `ca-app-pub-6138624088986178/4990989256` |
| Banner      | iOS      | `ca-app-pub-3940256099942544/2934735716` | `ca-app-pub-6138624088986178/1269723322` |
| Interstitial| Android  | `ca-app-pub-3940256099942544/1033173712` | same (test, for now)                 |
| Interstitial| iOS      | `ca-app-pub-3940256099942544/4411468910` | same (test, for now)                 |
| Rewarded    | Android  | `ca-app-pub-3940256099942544/5224354917` | `ca-app-pub-6138624088986178/2840036851` |
| Rewarded    | iOS      | `ca-app-pub-3940256099942544/2178118514` | `ca-app-pub-6138624088986178/7209425656` |

## Files Changed

- `lib/add/ad_helper.dart` — add `_useProductionIds => kReleaseMode` and resolve
  per-platform, per-mode IDs in the three existing getters.

## Unchanged

- Ad call sites (`header_banner_ad.dart`, `home_page.dart`,
  `workout_builder_page.dart`) — they already route through `AdHelper`.
- Error handling — non-Android/iOS platforms still throw `UnsupportedError`.

## Testing

- Existing ad widget tests run under `flutter test` (debug mode), so
  `kReleaseMode == false` and they continue to use test IDs; no behavior change.
- Add one unit test asserting:
  - in test mode (`kReleaseMode == false`), all getters return the Google test
    IDs for both platforms;
  - unsupported platforms throw `UnsupportedError`.
- Note: `kReleaseMode` is a compile-time const, so the test can only exercise
  the test-ID branch; the production branch is verified by code review + a
  release build smoke check.

## Non-code Follow-up (out of scope for this change)

- Host `app-ads.txt` correctly so AdMob doesn't block serving.
- Confirm fill status in the AdMob dashboard once the app is live.
- Add production interstitial IDs once available.
