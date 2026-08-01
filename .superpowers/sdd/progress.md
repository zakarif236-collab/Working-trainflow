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

## WIP cleanup (USER: "commit everything")
- Discarded: android/build (untracked build junk), third_party/flutter_tts/android/.gradle cache changes (reverted to HEAD).
- Commit 0d7db69 (feat: add AdMob infrastructure): pubspec.yaml/lock (+google_mobile_ads), lib/main.dart (MobileAds.initialize), lib/add/ad_helper.dart (new), AndroidManifest.xml (AdMob app id), proguard-rules.pro, macos GeneratedPluginRegistrant.swift. CRITICAL: committed code already imported google_mobile_ads/ad_helper; this commit made the branch build standalone.
- Commit 8b3d495 (chore: update app launcher icons and logo): assets/exercises/images/app_logo.png + android/app/icons/ (new), all mipmap/iOS AppIcon pngs, logo.png removed.
- Commit 3d003d4 (feat: hybrid sign-in with offline device uid, foreground service rework, timer/ad layout updates): auth_service, workout_foreground_service, audio_engine, community/first/home/main_shell/onboarding/schedule/timer pages, workout_player_widgets, workout_timer_layout, test/builder_builds_test.dart (new).
- Commit e70bf4e (docs: update superpowers progress ledger and task briefs/reports): .superpowers/sdd process files.
- Verification: working tree CLEAN; flutter analyze 13 issues (infos + 2 unused_field warnings in workout_foreground_service, pre-existing pattern); flutter test 13 pass / 3 pre-existing widget_test.dart Firebase failures (no regressions).
