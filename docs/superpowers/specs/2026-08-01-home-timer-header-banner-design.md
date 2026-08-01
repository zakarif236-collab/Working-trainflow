# Home Timer Header Banner Ad — Design

Date: 2026-08-01

## Overview

Add a small AdMob banner to the right of the "Immersive Workout Timer" title in the home timer header. The banner lives entirely inside the header row so it never pushes the circular timer or other content downward. The title and subtitle remain left-aligned.

## Requirements

1. A small AdMob banner appears to the right of the "Immersive Workout Timer" title in the home timer header.
2. The title and subtitle stay left-aligned.
3. The banner occupies only the header area — it must not push the timer or other content downward.
4. The banner is scaled down to roughly half its natural size (≈160x25) so the title keeps most of the header width.
5. When the ad has not yet loaded (or fails), no placeholder is shown — the header renders exactly as it does today.

## Architecture

### New widget: `HeaderBannerAd` (lib/widgets/header_banner_ad.dart)

A self-contained `StatefulWidget` that owns its ad lifecycle:

- `initState` loads a `BannerAd`:
  - `adUnitId`: `AdHelper.bannerAdUnitId` (existing test ID in `lib/add/ad_helper.dart`).
  - `size`: `AdSize.banner` (320x50).
  - `listener`: `BannerAdListener` with `onAdLoaded` (store the ad via `setState`) and `onAdFailedToLoad` (dispose the ad; leave state null).
- `dispose` disposes the loaded ad.
- `build`:
  - If the ad is null, return `const SizedBox.shrink()`.
  - Otherwise render the scaled-down ad:
    - `SizedBox(width: 160, height: 25)` containing a `FittedBox` wrapping a `SizedBox(width: 320, height: 50)` containing `AdWidget(ad: ad)`. `FittedBox` scales the 320x50 ad by 0.5 to fit 160x25.

### Integration: home_timer_layout.dart

In the header `Row` (lines 71-133), after the `Expanded` title column, append:

- `const SizedBox(width: 10)`
- `const HeaderBannerAd()`

Because the banner is a child of the same header `Row` (outside the `Expanded` `ListView` below), it cannot displace the timer or any lower content.

The `HeaderBannerAd` widget is only added to the home timer header. The workout player layout (`WorkoutTimerLayout`) is unchanged.

## Data Flow

1. `HomeTimerLayout` builds its header row, instantiating `HeaderBannerAd`.
2. `HeaderBannerAd` starts loading the banner on `initState`.
3. On load success, the widget rebuilds to show the scaled-down `AdWidget`.
4. On failure, the widget stays empty; the header matches today's layout.

## Error Handling

- `onAdFailedToLoad`: dispose the failed ad and keep `_bannerAd` null. No user-visible error, no placeholder.
- `dispose`: always dispose a non-null loaded ad to avoid leaks.

## Testing

- Widget test (or manual check): the `HeaderBannerAd` renders `SizedBox.shrink()` while no ad is loaded, and renders the scaled-down `AdWidget` once loaded.
- Manual: open the home timer on a device; verify the small banner appears to the right of the title, the title/subtitle are still left-aligned, and the circular timer's position is unchanged with and without a loaded ad.
- `flutter analyze` passes.
