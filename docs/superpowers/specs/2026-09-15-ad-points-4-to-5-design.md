# Design: Builder Points Tweak (Start 4, Ads +1)

Date: 2026-09-15

## Goal

- Grant new users **4** starting build points (was 1).
- Grant **1** build point per rewarded ad watch (was 4).
- Keep the daily ad cap and the auto-regeneration unchanged.

## Existing System

- Starting build points: initialized to 1 (`settings_service.dart` `loadBuilderBuildsRemaining`)
- `_kBuildPointsPerAd = 4` (`workout_builder_page.dart`)
- `_kMaxDailyAdWatches = 5` — max rewarded ad watches per day
- `kBuilderRegenerationEnabled = true` — 1 point auto-reimbursed every 2 days after a free-build spend
- `EarnPointsCard` button label interpolates the constant: "Watch Ad (+$pointsPerAd)"
- Out-of-builds dialog interpolates it: "unlock $_kBuildPointsPerAd extra builds now"

## Changes

1. `settings_service.dart`: initial grant `1` → `4`.
2. `workout_builder_page.dart`: `_kBuildPointsPerAd = 4` → `1`.
3. `workout_builder_page.dart`: UI default `_builderBuildsRemaining = 1` → `4` (display-only; overwritten by service load).
4. `workout_builder_page.dart`: dialog grammar pluralizes correctly for 1 ("unlock 1 extra build").

All UI labels interpolate the constant, so the button and dialog text update automatically.

## Deliberately Unchanged

- Daily ad cap of 5 (`_kMaxDailyAdWatches`)
- Auto-regeneration of 1 point every 2 days
- Free-build spend behavior (arms the 2-day regen timer; ad-finish does not)

## Testing

- `test/builder_builds_test.dart`: initial-grant assertion 1 → 4, consume after grant 0 → 3.
- `builder_build_regen_test.dart`, `earn_points_card_test.dart`: unchanged (set explicit states; card test passes its own `pointsPerAd`).
- Run `flutter test` and `flutter analyze`; the 3 pre-existing `widget_test.dart` pending-timer failures remain (baseline).