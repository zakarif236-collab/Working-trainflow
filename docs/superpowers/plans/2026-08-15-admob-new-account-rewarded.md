# AdMob New Account Rewarded Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Point the app's production rewarded ads at the new AdMob account's rewarded unit for both Android and iOS, keeping Google test IDs in debug/profile.

**Architecture:** Third and final swap in the AdMob account migration (banner → interstitial → rewarded). `AdHelper.adUnitIdFor` already gates on `production` (derived from `kReleaseMode`); only the two rewarded cases change. Tests assert the new production ID.

**Tech Stack:** Flutter, `google_mobile_ads` 9.0.0, Dart.

## Global Constraints

- Production rewarded unit ID (both platforms): `ca-app-pub-3222893031015336/4804623122`
- App ID stays `ca-app-pub-3222893031015336~9049517717` — do NOT touch `AndroidManifest.xml`, `Info.plist`, or `workout_builder_page.dart`.
- Debug/profile test IDs unchanged: Android rewarded `ca-app-pub-3940256099942544/5224354917`, iOS rewarded `ca-app-pub-3940256099942544/2178118514`.
- Banner and interstitial IDs unchanged — out of scope.
- Windows/PowerShell environment. No `gh` CLI, no `rg` (use `git grep`).
- Baseline: `flutter test` = 55 pass / 3 known pre-existing pending-timer failures in `test/widget_test.dart`. `flutter analyze` has 17 pre-existing issues, none in changed files.

---

### Task 1: Swap production rewarded IDs

**Files:**
- Modify: `lib/add/ad_helper.dart:76-82`
- Modify: `test/ad_helper_test.dart:58-67`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor(AdPlatform, AdType, {required bool production})` — returns `String`.
- Produces: No new interfaces. `AdHelper.rewardedAdUnitId` now resolves to the new production unit in release builds. `workout_builder_page.dart` consumes it unchanged via `_loadRewardedAd` (`lib/pages/workout_builder_page.dart:107`).

- [ ] **Step 1: Update the production rewarded expectations in the test**

In `test/ad_helper_test.dart`, replace the two production rewarded expectations (currently lines 58-67) so they assert the new unit ID:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.rewarded,
            production: true),
        'ca-app-pub-3222893031015336/4804623122',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.rewarded,
            production: true),
        'ca-app-pub-3222893031015336/4804623122',
      );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ad_helper_test.dart`
Expected: the `uses production IDs when production is true` test FAILS — Android rewarded expectation got `ca-app-pub-6138624088986178/2840036851` but expected `ca-app-pub-3222893031015336/4804623122`.

- [ ] **Step 3: Update the rewarded cases in `ad_helper.dart`**

Replace the two production rewarded ternaries (currently lines 76-82) with:

```dart
      case (AdPlatform.android, AdType.rewarded):
        return production
            ? 'ca-app-pub-3222893031015336/4804623122'
            : 'ca-app-pub-3940256099942544/5224354917';
      case (AdPlatform.ios, AdType.rewarded):
        return production
            ? 'ca-app-pub-3222893031015336/4804623122'
            : 'ca-app-pub-3940256099942544/2178118514';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS (all 3 tests).

- [ ] **Step 5: Run analyzer**

Run: `flutter analyze`
Expected: no new issues in `lib/add/ad_helper.dart` or `test/ad_helper_test.dart`.

- [ ] **Step 6: Commit**

```bash
git add lib/add/ad_helper.dart test/ad_helper_test.dart
git commit -m "feat(ads): use new production rewarded ad unit IDs"
```

---

### Task 2: Verification

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: Task 1 output on the current branch.

- [ ] **Step 1: Confirm the only ID diffs are rewarded**

Run: `git diff origin/master..HEAD -- lib/add/ad_helper.dart`
Expected: exactly the two rewarded cases changed; banner, interstitial, and debug cases identical to before.

- [ ] **Step 2: Confirm debug test IDs unchanged in source**

Run: `git grep "3940256099942544/5224354917" lib/add/ad_helper.dart`
Expected: 1 match (the Android rewarded debug ID).
Run: `git grep "3940256099942544/2178118514" lib/add/ad_helper.dart`
Expected: 1 match (the iOS rewarded debug ID).

- [ ] **Step 3: Confirm old-account rewarded IDs fully gone from lib/test**

Run: `git grep "6138624088986178" lib test`
Expected: NO matches in `lib` or `test` (the old rewarded IDs are fully removed from source).

- [ ] **Step 4: Run full ad test suite**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS, all 3 tests.

- [ ] **Step 5: Build release APK**

Run: `flutter build apk --release`
Expected: builds successfully (`app-release.apk`).

- [ ] **Step 6: Commit any lock/state changes if present**

Run: `git status --porcelain`
If only build artifacts (`build/`, `.gradle/`, generated plugin registrants) show, do NOT commit — they are intentionally excluded. If source files changed unexpectedly, investigate and amend Task 1's commit. Otherwise no commit needed.
