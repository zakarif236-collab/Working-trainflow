# Design: Rewarded-Ad Points Increase (4 → 5)

Date: 2026-09-15

## Goal

Change the number of build points earned per rewarded ad watch from 4 to 5.

## Existing System

- `_kBuildPointsPerAd = 4` (lib/pages/workout_builder_page.dart:87)
- `_kMaxDailyAdWatches = 5` — max rewarded ad watches per day
- `kBuilderRegenerationEnabled = true` — 1 point auto-reimbursed every 2 days after a free-build spend
- `EarnPointsCard` button label interpolates the constant: "Watch Ad (+$_kBuildPointsPerAd)"
- Out-of-builds dialog interpolates it: "unlock $_kBuildPointsPerAd extra builds"

## Change

Change `_kBuildPointsPerAd` from `4` to `5` in `lib/pages/workout_builder_page.dart`.

All UI labels interpolate the constant, so the button and dialog text update automatically.

## Deliberately Unchanged

- Daily ad cap of 5 (`_kMaxDailyAdWatches`)
- Auto-regeneration of 1 point every 2 days

## Testing

No test changes needed: `test/earn_points_card_test.dart` passes an explicit
`pointsPerAd: 4` to the widget, so it is independent of the constant. After the
change, run `flutter test` and `flutter analyze`; the 3 pre-existing
`widget_test.dart` pending-timer failures remain (baseline).