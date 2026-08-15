# Task 4 Report: Full verification — analyze, tests, release config sanity

**Status: DONE_WITH_CONCERNS**

## 1. `flutter analyze`

Ran `flutter analyze` in the worktree. Result: **17 issues found** (2 errors, 15 infos) — NOT "No issues found".

All 17 are **pre-existing baseline issues, none introduced by this plan**:

- 2 errors in `third_party/flutter_tts/example/test/widget_test.dart` (vendored third-party package, `uri_does_not_exist` / `undefined_function`).
- 15 infos in app + third_party code: `avoid_print` in `lib/pages/community_page.dart`, `lib/pages/home_page.dart`, `lib/pages/workout_builder_page.dart`, `lib/services/community_firestore_service.dart`; `avoid_types_as_parameter_names` in `community_firestore_service.dart`; `deprecated_member_use` (EquatableMixin) + `invalid_runtime_check_with_js_interop_types` in third_party packages.

Evidence these are not regressions:
- The plan's three commits (d76d71f, 93dcc64, 319149b) touch ONLY `android/app/src/main/AndroidManifest.xml`, `ios/Runner/Info.plist`, `lib/add/ad_helper.dart`, `test/ad_helper_test.dart` — none of which appear in the analyze output.
- `git status`/`git diff` shows no uncommitted changes to any Dart file (only `.superpowers/*` scratch and linux/macos/windows generated plugin registrant files, which are not analyzed Dart).
- Therefore every flagged file is byte-identical to the pre-plan base, and analyze would produce the identical issue list on the base.

Note: the brief's expectation of "No issues found" does not hold for this repo's actual baseline. This is a pre-existing condition, not a regression from Tasks 1–3.

## 2. `flutter test`

Ran the full `flutter test` suite. Result: **48 passed / 3 failed** (51 total).

The 3 failures are exactly the documented baseline pending-timer failures in `test/widget_test.dart`, all with the same root cause ("A Timer is still pending even after the widget tree was disposed", an 8s timer from `_FirstPageState._loadInsights` → `SettingsService.loadInsightsFromFirestore`):

1. `Calisthenics quick start opens workout page`
2. `VO2max quick start opens workout page`
3. `Workout timer is shown by default on home tab`

All other tests pass, including every banner/ad-related test called out in the brief: `test/ad_helper_test.dart` (3 tests), `test/header_banner_ad_test.dart` (3), `test/scaled_banner_ad_test.dart` (1), `test/builder_ad_watches_test.dart` (6). No new failures, no regressions.

## 3. Release-mode ID resolution (`git grep`)

Ran `git grep -n "3222893031015336" -- android ios lib test` (scoped per brief Step 3; `rg` not installed). Result: **exactly 6 matches**, as expected:

```
android/app/src/main/AndroidManifest.xml:20:  android:value="ca-app-pub-3222893031015336~9049517717"/>
ios/Runner/Info.plist:8:                        <string>ca-app-pub-3222893031015336~9049517717</string>
lib/add/ad_helper.dart:63:                       ? 'ca-app-pub-3222893031015336/8843106337'
lib/add/ad_helper.dart:67:                       ? 'ca-app-pub-3222893031015336/8843106337'
test/ad_helper_test.dart:42:                     'ca-app-pub-3222893031015336/8843106337',
test/ad_helper_test.dart:46:                     'ca-app-pub-3222893031015336/8843106337',
```

Breakdown: App ID (2 config matches: Android manifest + iOS Info.plist), banner production ID (2 in `ad_helper.dart`, 2 in `ad_helper_test.dart`), and no other files under android/ios/lib/test.

Note: an *unscoped* `git grep` returns additional matches only in plan bookkeeping/docs: `.superpowers/sdd/task-1..4-brief/report.md` and `docs/superpowers/specs/2026-08-15-admob-new-account-banner-design.md`. These are documentation/scratch, not source, and match the brief's own scoping (`rg ... lib test android ios`).

## 4. Repo hygiene

- Plan commits are clean and minimal: `d76d71f` (Android manifest + iOS Info.plist), `93dcc64` (ad_helper.dart), `319149b` (ad_helper_test.dart).
- Unrelated modified files present (as expected): `.superpowers/*` scratch and `linux/macos/windows` generated plugin registrants. Nothing staged, nothing committed.

## Concerns

1. **`flutter analyze` is not clean** — 17 pre-existing issues (incl. 2 errors in vendored `third_party/flutter_tts`). Unrelated to this plan and present on the base; flagged here only because the brief's "No issues found" expectation doesn't match the repo's real baseline.
2. The brief's `ALL PASS` test expectation was superseded by the known 3-baseline-failure baseline; observed behavior matches that documented baseline exactly.

## No commit

Per task instructions, no commit was made (Task 4 has no code changes).
