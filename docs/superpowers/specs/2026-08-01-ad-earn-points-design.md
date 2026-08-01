# Earn Build Points by Watching Ads — Design

Date: 2026-08-01

## Overview

Replace the current "watch one rewarded ad = +2 builds" reward model with a simple, repeatable "1 ad = 1 build point" model. Users earn build points in a dedicated **Earn Points** card on the Workout Builder page, capped at 5 per day. Build points are consumed when saving a new workout, unchanged from the current behavior.

## Requirements

1. Watching a rewarded ad awards exactly **1 build point**.
2. Watching another ad awards another point (repeatable within the daily cap).
3. Daily cap: **5 ad-watch points per day**. The button is disabled once the cap is reached and resets the next day.
4. A dedicated **Earn Points** card appears above the builder section on the Workout Builder page.
5. The existing save-flow ad prompt changes from +2 builds to +1 build (1 ad = 1 point).
6. The initial free build of 1 remains unchanged.

## Architecture

### SettingsService (persistence)

Add two methods backed by SharedPreferences:

- `Future<int> loadAdWatchCountForToday()` — returns the count of rewarded ads watched today.
- `Future<void> recordAdWatchForToday()` — increments today's count.

Persistence: a single JSON string key `builder.adWatches` storing `{ "date": "2026-08-01", "count": 3 }`. When `date` no longer matches today's date, the count resets to 0. Today's date is compared using calendar-day granularity (matching the existing `_epochDay` helper pattern in `SettingsService`).

New shared preference keys:

- `builder.adWatches` — JSON map of `{date, count}`.

### WorkoutBuilderPage (UI + ad flow)

Reuse the existing rewarded-ad plumbing already in the page:

- `_loadRewardedAd()` — loads a fresh rewarded ad.
- `_showRewardedAd(VoidCallback onReward)` — shows the ad and invokes the callback on reward.

Add an **Earn Points** card widget (`_EarnPointsCard`) placed above the "Create Workout" card in the `ListView` when `widget.showBuilder` is true.

The card displays:

- Current build points balance (e.g., "3 build points").
- A "Watch Ad (+1)" button that plays the rewarded ad; on reward it calls `recordAdWatchForToday()` then `addBuilderBuilds(1)`, and refreshes the balance and daily counter.
- Daily progress (e.g., "2/5 today"). The button is disabled when the count is >= 5.
- A helper line: "Watch ads to earn build points, used when you save a new workout."

State additions to `_WorkoutBuilderPageState`:

- `int _todayAdWatches = 0;` — number of rewarded ads watched today.
- A constant `_kMaxDailyAdWatches = 5`.

`initState()` also calls `loadAdWatchCountForToday()` to initialize the counter.

### Save-flow change

In `_saveRoutine()` (`workout_builder_page.dart:284`), change the reward from:

```dart
await _settingsService.addBuilderBuilds(2);
```

to:

```dart
await _settingsService.addBuilderBuilds(1);
```

so the save-flow ad also follows the "1 ad = 1 point" rule.

## Data Flow

1. User opens Workout Builder → `initState` loads `buildsRemaining` and `adWatchCountForToday`.
2. User taps "Watch Ad (+1)" → `_showRewardedAd` plays the ad.
3. On reward: `recordAdWatchForToday()` → `addBuilderBuilds(1)` → `setState` updates balance and counter.
4. At 5 watches, button disabled. Next calendar day, `loadAdWatchCountForToday` sees a stale date and resets to 0.

## Error Handling

- If the rewarded ad is not loaded, `_showRewardedAd` already shows a "not ready" message and reloads. No change needed.
- If the ad fails to show, the existing `onAdFailedToShowFullScreenContent` handler shows a message and reloads. No points are awarded (callback only fires on `onUserEarnedReward`).
- If the daily counter read fails (corrupt JSON), `loadAdWatchCountForToday` falls back to 0 (consistent with `_decodeIntMap` error handling in `SettingsService`).

## Testing

- Unit test `SettingsService.loadAdWatchCountForToday` / `recordAdWatchForToday`:
  - Returns 0 when no key is stored.
  - Increments across multiple calls.
  - Resets to 0 when the stored date is a previous calendar day.
  - Falls back to 0 on corrupt JSON.
- Widget/behavioral check (manual or widget test): tapping "Watch Ad (+1)" on a fake reward increments the balance and daily counter; button disables at 5.
- Verify the save-flow prompt now grants +1 instead of +2.
