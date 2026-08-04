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

## Plan: docs/superpowers/plans/2026-08-03-workout-progress-firestore-sync.md
## BASE: 6146a1e

## Tasks
| # | Task | Status | Commit | Review |
|---|------|--------|--------|--------|
| 1 | sessionsToFirestoreMap helper + tests | done | 033dfa6 | approved |
| 2 | syncWorkoutProgressToFirestore + buildWorkoutSyncData | done | d32092d | approved |
| 3 | saveInsightsToFirestore includes session history | done | 5470388 | approved |
| 4 | loadRecentSessionsFromFirestore + pickNewerInsights | done | 5f92099 | approved |
| 5 | Profile load restores newer source + Firestore sessions | done | 30af722 | approved |
| 6 | Sync on app launch and resume | done | bcd749d | approved |
| 7 | Draft firestore.rules | done | ac5000b | approved |

## Pre-flight decisions (user-approved 2026-08-03)
- Tasks 2-3 share a tested `buildWorkoutSyncData` helper (no duplicated stat-field map); Task 3's vacuous smoke test removed, real helper assertions added in Task 2.
- Task 7 rules access matrix approved as drafted.

## Minor findings (roll-up for final review)
- T1: empty-list and exactly-30 cases untested in sessionsToFirestoreMap (minor, no action).
- T1: duplicate completedAt millis silently overwrite in the map (inherent to millis-keyed design, informational).
- T1: report claimed test file 52 lines; committed file is 35 (reporting inaccuracy, not code).
- T2: no-op/completion tests print `[core/no-app]` via the sync catch debugPrint (plan-mandated, acceptable noise).
- T2: no test verifies the actual Firestore write; completion test would pass identically without the hook (inherent to no-Firebase env).
- T2: no-op test has no expect() — weakest of the three (fine per brief).
- T4: loader `loadRecentSessionsFromFirestore` has zero test coverage (Firestore-backed, untestable without emulator; plan-mandated).
- T4: pickNewerInsights equality branch (equal lastWorkoutAt → local) and remoteAt==null branch untested (minor).
- T6: launch-call ordering after auth init verified by controller (main.dart:76, auth init at 42-61) — ⚠️ resolved, not a gap.
- T7: report claimed rules file "byte-for-byte" identical to brief but added explanatory comment blocks (cosmetic, logic faithful).

## Plan: docs/superpowers/plans/2026-08-03-multi-device-sync-convergence.md
## BASE: c09af61

## Tasks
| # | Task | Status | Commit | Review |
|---|------|--------|--------|--------|
| 1 | Shared session storage cap constant (30 -> 100) | done | a6d0e8f | approved |
| 2 | mergeSessionsByTimestamp session union | done | 9d1ee20 | approved |
| 3 | computeStreaks (current, best) | done | c0c5116 | approved |
| 4 | resolveInsights conflict-safe scalars | done | e82d81b | approved |
| 5 | mergeRemoteInsights orchestrator | done | e9feb73 | approved |
| 6 | Profile page renders/persists merged union | done | c6d0554 | approved |
| 7 | Firestore rules deploy wiring + admin claim | done | 6e5006c | approved |
| 8 | Full suite verification | done | - | approved |

## Minor findings (roll-up for final review)
- T1: reviewer confirmed plan's Task 1 site list was INCOMPLETE — a sixth storage/sync cap site exists at `saveInsightsToFirestore` (~settings_service.dart:854). Implementer replaced it too; justified by global constraint (cap at every storage/sync site). Later tasks must not assume plan site lists exhaustive.
- T1 (minor): `lib/pages/first_page.dart:56` `loadRecentSessions(limit: 30)` — UI display site, hardcoded 30, pre-existing, outside Task 1 scope; reconcile with display-cap intent during Task 6 (touches this file).
- T1 (minor): only site E (`sessionsToFirestoreMap`) has a cap test; `loadRecentSessionsFromFirestore` 100-cap and `recordWorkoutCompletion` local-store 100-cap unpinned. Breadth gap, not defect.
- T2 (minor): empty-input path `([], [])` and same-timestamp remote-wins tie-break not directly asserted (implicitly covered). Optional coverage polish, no action.
- T3 (plan-premise note): plan claimed loadInsights() computes streaks via a local closure returning "oldest segment" — FALSE. git log -S confirms no computeStreaks ever existed; loadInsights() reads streaks from prefs (:811-812); streak VALUES written incrementally in recordWorkoutCompletion (:996-1015). Concrete deliverables were self-contained; implemented verbatim. Decide whether to correct plan's Task 3 context for the record.
- T3 (minor): no test for current < best case ([10,2,1] → (1,2)) or same-day dedup; one-liner additions suggested.
- T4 (plan-internal contradiction, controller-adjudicated): brief test passed ASCENDING union [1000..4000] expecting lastWorkoutAt 4000, but verbatim impl uses mergedSessions.first.completedAt (descending contract). Controller approved Option B: keep impl verbatim, change test union to descending [4000,3000,2000,1000]. Plan's Task 4 test snippet should be corrected in the plan doc for the record.
- T4 (minor, disclosed): fold accumulator renamed sum → total to avoid avoid_types_as_parameter_names lint (semantics unchanged). No test for empty-union recompute or _later tie-break. Near-duplicate max ternaries; recompute test doesn't assert streaks and uses identical displayName so pickNewerInsights selection isn't truly verified.
- T5 (plan-mandated): mergeRemoteInsights always persists (no no-remote short-circuit) — adjudicated OK; reviewer proved recompute-from-local-only cannot drop loadInsights() data in any consistent state. PLAN-MANDATED GAP for final review: mergeRemoteInsights itself has no direct test (7-key persistence, profile-key exclusion, null-lastWorkoutAt skip) — loaders are Firestore-backed; plan accepted this. Reviewer suggests SharedPreferences-mock test with stubbed loaders.
- T5 (minor): converge test passes identical insightsAt() args to both resolveInsights calls and asserts only totals; streak/lastWorkoutAt equality unasserted. Stale lastWorkout keys possible if a session-pruning path ever appears (unreachable now, plan-mandated if-branch).
- T6 (minor): _recentSessions = result.sessions now unconditionally overwrites local (old code kept local when remoteSessions empty) — brief-mandated; keep-local decision lives in mergeRemoteInsights (T5), which returns local when remote empty. OK.
- T6: first_page.dart online branch simplified to single mergeRemoteInsights call; pickNewerInsights/load*FromFirestore no longer referenced there (verified by reviewer grep).
- T7 (plan-mandated text bug): brief's verbatim firebase.json was INVALID (9 opens / 8 closes; would nest firestore inside flutter). Implementer inserted exactly one `}` before `,"firestore"`; reviewer independently verified: valid JSON, byte-equivalent to base except firestore section, top-level keys flutter,firestore. Plan's Task 7 Step 1 JSON string should be corrected for the record.
- T7 (manual dependency): rules now require admin:true custom claim — hard behavioral dependency until Step 5 checklist (Admin SDK setCustomUserClaims, firebase deploy --only firestore:rules, verify admin/non-admin delete) is executed. Documented for user; not run.

## Task 8 verification (controller-run)
- `flutter test` full suite: 30 passed, 3 failed — exactly the pre-existing widget_test.dart timer-pending failures (Calisthenics quick start / VO2max quick start / Workout timer shown by default), same as baseline. Sync file: 15/15 pass.
- `flutter analyze`: 11 issues, all pre-existing info lints in OTHER files (community_page.dart, home_page.dart, workout_builder_page.dart, community_firestore_service.dart). No new issues.
- Manual smoke test (two-device offline convergence) NOT run — requires physical devices; documented for user in plan Task 8 Step 3.

## Final branch review (controller-run, base c09af61 → head 6e5006c)
- Verdict: ✅ APPROVED. Every seam consistent (JSON format, prefs keys, cap semantics, Firestore round-trip); primary online/offline/multi-device paths converge without losing history; rules wiring sound.
- IMPORTANT finding (FIXED, USER-APPROVED): recompute path in resolveInsights was not monotonic — legacy cap-30 offline histories (counter 60, only 30 sessions) would recompute to 30 and persist the drop permanently. Fixed in commit 4612738 ("fix: make resolveInsights recompute monotonic for legacy cap-30 histories"): recomputed totalWorkouts/totalSeconds now max against local/remote stored counters. Added regression test "resolveInsights never drops counters below the stored monotonic max". Sync tests now 16/16; analyze unchanged (11 pre-existing infos).
- Minor findings (documented, no action): truncated-union under-count for 100+10 split histories is design-inherent (spec §2 trade-off); display count varies 30 (offline load) ↔ 100 (online result.sessions), neither matches design's stated 7; profile fields converge render-only (merge persist writes scalar keys only); corrupt-prefs parse→empty-union→zeroed-counters clobber risk; mergeRemoteInsights has no direct test (plan-mandated, Firestore-backed loaders).
- Post-fix: full suite re-run on 4612738 HEAD — 16 sync tests pass; whole-suite 30 pass + 3 pre-existing widget_test timer failures (baseline).

## Plan: docs/superpowers/plans/2026-08-04-foreground-gating-and-offline-firstframe.md
## BASE: 70a2103

## Tasks
| # | Task | Status | Commit | Review |
|---|------|--------|--------|--------|
| 1 | Gate companion notification on foreground state | done | 6a1ad4e | approved |
| 2 | Decouple first frame from auth resolution on cold start | done | e183748 | approved |

## Task 1 review
- Verdict: ✅ Spec compliant, Approved. All 6 code steps verbatim; commit touched only workout_foreground_service.dart; no tests (correct per spec constraint).
- Manual device checklist (brief Steps 1-6) NOT runnable in this environment — USER must verify on device before merge.
- Minor (roll-up for final review): `_isForegrounded` name is semantically inverted (true = backgrounded/locked); plan-mandated name, doc comment disambiguates. No action.

## Task 2 review
- Verdict: ✅ Spec compliant, Approved. Old main() fully replaced (no duplicates); ordering/timeouts preserved exactly; runApp reached on every path; commit scoped to lib/main.dart only.
- Brief extraction encoding artifact: controller's PowerShell brief emitted mojibake (â€”/âœ…) from reading UTF-8-no-BOM plan as ANSI; implementer reproduced intended Unicode; committed file clean.
- Manual device checklist (airplane-mode cold start, reconnect clobber, deep links) NOT runnable in this environment — USER must verify on device before merge.
- Minor (roll-up for final review): `FirebaseMessaging.onBackgroundMessage` (main.dart:114) only deferred statement outside try/catch (verbatim per brief; non-throwing sync registration; previously ran pre-runApp). `await Firebase.initializeApp` (main.dart:34) unwrapped pre-runApp (pre-existing, per brief). No action.

## Final whole-branch review (70a2103 → e183748)
- Verdict: ✅ Ready to merge — Yes. Both fixes faithful to plan; cross-task ordering correct (cancelStaleNotifications still completes before runApp; _finalizeStartup never touches _isForegrounded); flag can't get stuck; _finalizeStartup crash-safe; scope discipline (only the 2 listed files).
- IMPORTANT (pre-existing, OUT of plan scope, follow-up recommended, NOT blocking): `cancelStaleNotifications()` (workout_foreground_service.dart:52-58) cancels only `_notificationId` (888), never `_actionNotificationId` (889). Process killed while backgrounded with a running workout → companion notification lingers with dead buttons. One-liner fix: also `await plugin.cancel(_actionNotificationId)`. USER: decide whether to do as follow-up commit.
- Minor (no action): deep-link init now races identity settling (low risk — resolvedUserId stable from AuthService.init); AppLifecycleListener registered before _finalizeStartup completes (duplicate idempotent sync, harmless); first frame can render before NotificationService.load() (cosmetic badge flash); per-task roll-ups all no-ops.
- Manual device checklists (Task 1 items 2/4/5, Task 2 items 1/2/4) NOT yet run — REQUIRED before release. Also recommended: kill-from-recents stale-889 check.

## Completion (2026-08-04)
- USER: "Merge back to master locally". Handled uncommitted WIP first (USER: "Commit all + discard gradle junk") → commit f09aa36 (chore: commit pre-merge WIP: firebase options appId, schedule load hardening, SDD ledger + plan docs).
- Merge: fast-forward aefd461 → f09aa36 on master; branch feat/hybrid-signin-offline deleted.
- Merged-result verification: flutter test 37 pass / 3 pre-existing widget_test timer-pending failures (baseline, no regressions).
- NOTE for USER: f09aa36 carried `lib/firebase_options.dart` appId `3bfacc3d4296109065577f` (com.TrainFlow.myapp client) while applicationId is com.trainflow22.app — inconsistent; verify before release.
- OPEN follow-up (recommended by final review, NOT done): `cancelStaleNotifications()` should also cancel `_actionNotificationId` (889) — kill-from-recents stale companion notification.
- Pending: manual device checklists before release.

## Notes
- Worktree at dispatch: uncommitted `lib/firebase_options.dart` (appId → com.TrainFlow.myapp client) and `lib/widgets/workout_schedule_section.dart` (try/catch hardening) exist; OUTSIDE plan scope — implementers stage only their scoped file per plan commit steps.
- Subagents dispatched without explicit model (OpenCode task tool has no model param — session default used for all roles).
