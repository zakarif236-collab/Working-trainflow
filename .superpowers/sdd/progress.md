# Earn Build Points by Watching Ads — Progress Ledger

## Plan: docs/superpowers/plans/2026-08-01-ad-earn-points.md
## BASE: 169e7dc

## Tasks

| # | Task | Status | Commit | Review |
|---|------|--------|--------|--------|
| 1 | SettingsService daily ad-watch persistence | done | eaac52c | approved |
| 2 | EarnPointsCard widget | done | 66303f3 | approved |
| 3 | Wire card into page + save-flow +1 | done | cba9a6c | approved |

## Pre-flight decisions
- Plan governs over spec: `EarnPointsCard` is a public widget in `lib/widgets/earn_points_card.dart` (testable in isolation), not a private `_EarnPointsCard` in the page. (User decision)

## Minor findings (roll-up for final review)
- T1 commit eaac52c bundled uncommitted builder-builds WIP from settings_service.dart (loadBuilderBuildsRemaining/consumeBuilderBuild/addBuilderBuilds + _kBuilderBuilds* consts); plan assumed committed. Functional, Task 3 depends on it. USER: accept bundle, proceed.
- T1 tests: round-trip tests assert via loadAdWatchCountForToday, so a shared wrong key/format would pass unnoticed; a raw-prefs assertion would lock the storage contract. (plan-mandated, minor)
- T1: recordAdWatchForToday calls DateTime.now() twice when now==null (read then write); midnight-boundary edge, verbatim from brief. (minor, no action)
- T2: singular copy '1 build point' untested (only plural asserted); test name "disabled when the daily cap is reached" misleading — cap-based disabling is Task 3's job, widget only disables on onWatchAd==null. (minor, naming mislabel originates in brief)
- T3: _todayAdWatches loaded once in initState; day-rollover while page alive goes stale until restart (matches brief design, informational).
- T3: _watchAdForPoint passes async closure as VoidCallback into _showRewardedAd, un-awaited (pre-existing mechanism, not introduced).
- T3: no new automated test — page can't be pumped (Firebase at field-init throws); plan-mandated, verified.

## Final branch review
- Base 169e7dc → Head cba9a6c. Verdict: ✅ complete and coherent; APPROVED.
- Minor findings (none blocking): save-flow ads bypass the daily-cap counter (named edge, spec scoped cap to card button); midnight rollover of in-memory counter until reopen (no count lost); pre-existing _loadRewardedAd setState without mounted guard + leaked ad reload (pre-existing plumbing); save-flow "Watch Ad" silently dropped when ad not ready (draft preserved); T3 commit sweep broader than disclosed — also carries import-from-link feature + _attachMedia changes (functional, unrelated).
- Feature delivered: rewarded ad = 1 build point, repeatable ≤5/day, cap resets next day, EarnPointsCard above builder card, save-flow reward unified to +1, initial free build unchanged.

## Completion
- USER: Keep branch feat/hybrid-signin-offline as-is. Feature commits eaac52c / 66303f3 / cba9a6c remain on branch. Final test run: 13 pass, 3 pre-existing widget_test.dart Firebase [core/no-app] failures (unrelated, out of scope). DONE.
