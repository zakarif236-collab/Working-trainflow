# AdMob New Account Interstitial Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Point the app's production interstitial ads at the new AdMob account's interstitial unit for both Android and iOS, keeping Google test IDs in debug/profile.

**Architecture:** Follows the exact pattern of the banner swap. `AdHelper.adUnitIdFor` already gates on `production` (derived from `kReleaseMode`); only the two interstitial cases change. Tests assert the new production ID.

**Tech Stack:** Flutter, `google_mobile_ads` 9.0.0, Dart.

## Global Constraints

- Production interstitial unit ID (both platforms): `ca-app-pub-3222893031015336/1741873338`
- App ID stays `ca-app-pub-3222893031015336~9049517717` — do NOT touch `AndroidManifest.xml` or `Info.plist`.
- Debug/profile test IDs unchanged: Android interstitial `ca-app-pub-3940256099942544/1033173712`, iOS interstitial `ca-app-pub-3940256099942544/4411468910`.
- Rewarded IDs unchanged — out of scope.
- Windows/PowerShell environment. No `gh` CLI, no `rg` (use `git grep`).
- Baseline: `flutter test` = 48 pass / 3 known pre-existing pending-timer failures in `test/widget_test.dart`. `flutter analyze` has 17 pre-existing issues, none in changed files.

---

### Task 1: Swap production interstitial IDs

**Files:**
- Modify: `lib/add/ad_helper.dart:69-74`
- Modify: `test/ad_helper_test.dart:48-57`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor(AdPlatform, AdType, {required bool production})` — returns `String`.
- Produces: No new interfaces. `AdHelper.interstitialAdUnitId` now resolves to the new production unit in release builds.

- [ ] **Step 1: Update the production interstitial expectations in the test**

In `test/ad_helper_test.dart`, replace the two production interstitial expectations (currently lines 48-57) so they assert the new unit ID:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.interstitial,
            production: true),
        'ca-app-pub-3222893031015336/1741873338',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.interstitial,
            production: true),
        'ca-app-pub-3222893031015336/1741873338',
      );
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ad_helper_test.dart`
Expected: the `uses production IDs when production is true` test FAILS — Android interstitial expectation got `ca-app-pub-3940256099942544/1033173712` but expected `ca-app-pub-3222893031015336/1741873338`.

- [ ] **Step 3: Update the interstitial cases in `ad_helper.dart`**

Replace the two `TODO(ads)` interstitial cases (currently lines 69-74) with:

```dart
      case (AdPlatform.android, AdType.interstitial):
        return production
            ? 'ca-app-pub-3222893031015336/1741873338'
            : 'ca-app-pub-3940256099942544/1033173712';
      case (AdPlatform.ios, AdType.interstitial):
        return production
            ? 'ca-app-pub-3222893031015336/1741873338'
            : 'ca-app-pub-3940256099942544/4411468910';
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
git commit -m "feat(ads): use new production interstitial ad unit IDs"
```

---

### Task 2: Verification

**Files:**
- None (verification only)

**Interfaces:**
- Consumes: Task 1 output on the current branch.

- [ ] **Step 1: Confirm the only ID diffs are interstitial**

Run: `git diff origin/master..HEAD -- lib/add/ad_helper.dart`
Expected: exactly the two interstitial cases changed; banner and rewarded cases identical to before.

- [ ] **Step 2: Confirm debug test IDs unchanged in source**

Run: `git grep "3940256099942544/1033173712" lib/add/ad_helper.dart`
Expected: 1 match (the Android interstitial debug ID).
Run: `git grep "3940256099942544/4411468910" lib/add/ad_helper.dart`
Expected: 1 match (the iOS interstitial debug ID).

- [ ] **Step 3: Run full ad test suite**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS, all 3 tests.

- [ ] **Step 4: Build release APK**

Run: `flutter build apk --release`
Expected: builds successfully (`app-release.apk`).

- [ ] **Step 5: Commit any lock/state changes if present**

Run: `git status --porcelain`
If only build artifacts (`build/`, `.gradle/`, generated plugin registrants) show, do NOT commit — they are intentionally excluded. If source files changed unexpectedly, investigate and amend Task 1's commit. Otherwise no commit needed.
