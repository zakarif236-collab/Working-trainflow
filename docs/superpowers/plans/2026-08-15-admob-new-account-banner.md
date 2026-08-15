# AdMob New Account Banner Swap Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Point the app at the new AdMob account — swap the App ID in the platform config files and the production banner ad unit IDs in `AdHelper` — while keeping Google test IDs for debug/profile builds and leaving interstitial/rewarded slots untouched.

**Architecture:** `AdHelper.adUnitIdFor(platform, type, {required bool production})` (lib/add/ad_helper.dart) is the single source of truth for ad unit IDs, bound to Flutter's compile-time `kReleaseMode`. Only the two banner production values change. The App ID lives in `android/app/src/main/AndroidManifest.xml` (as `meta-data` `com.google.android.gms.ads.APPLICATION_ID` inside `<application>`) and `ios/Runner/Info.plist` (`GADApplicationIdentifier`).

**Tech Stack:** Flutter / Dart 3, `google_mobile_ads: ^9.0.0`, `flutter_test`.

## Global Constraints

- New App ID: `ca-app-pub-3222893031015336~9049517717` — MUST appear in both platform config files.
- New production banner ID: `ca-app-pub-3222893031015336/8843106337` — used for Android AND iOS banner release builds.
- Debug/profile banner builds MUST keep Google test IDs: Android `ca-app-pub-3940256099942544/6300978111`, iOS `ca-app-pub-3940256099942544/2934735716`.
- Interstitial IDs MUST NOT change: Android `ca-app-pub-3940256099942544/1033173712` (both modes), iOS `ca-app-pub-3940256099942544/4411468910` (both modes), TODOs stay.
- Rewarded IDs MUST NOT change: Android prod `ca-app-pub-6138624088986178/2840036851`, test `ca-app-pub-3940256099942544/5224354917`; iOS prod `ca-app-pub-6138624088986178/7209425656`, test `ca-app-pub-3940256099942544/2178118514`.
- Ad call sites (`header_banner_ad.dart`, `home_page.dart`, `workout_builder_page.dart`) MUST NOT change.
- `flutter analyze` and `flutter test` MUST pass with no new issues.

---

### Task 1: Swap App ID in Android manifest and iOS Info.plist

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml:18-20`
- Modify: `ios/Runner/Info.plist:7-8`

**Interfaces:**
- Consumes: nothing.
- Produces: platform config files that advertise the new App ID to the AdMob SDK at app launch. Later tasks depend only on `AdHelper`, not on these files directly, but ad serving requires the App ID to match the account owning the production banner unit.

- [ ] **Step 1: Update the Android manifest App ID**

Edit `android/app/src/main/AndroidManifest.xml` lines 18-20. Change only the `android:value`:

```xml
        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="ca-app-pub-3222893031015336~9049517717"/>
```

- [ ] **Step 2: Update the iOS Info.plist App ID**

Edit `ios/Runner/Info.plist` lines 7-8. Change only the string value:

```xml
	<key>GADApplicationIdentifier</key>
	<string>ca-app-pub-3222893031015336~9049517717</string>
```

- [ ] **Step 3: Verify the change is scoped correctly**

Run: `rg "ca-app-pub-3222893031015336" android ios`
Expected: exactly 2 matches — one in `android/app/src/main/AndroidManifest.xml`, one in `ios/Runner/Info.plist`.

- [ ] **Step 4: Commit**

```bash
git add android/app/src/main/AndroidManifest.xml ios/Runner/Info.plist
git commit -m "feat(ads): point App ID to new AdMob account"
```

---

### Task 2: Update production banner IDs in AdHelper

**Files:**
- Modify: `lib/add/ad_helper.dart:61-68`

**Interfaces:**
- Consumes: nothing from Task 1 (independent).
- Produces: `adUnitIdFor(AdPlatform.android, AdType.banner, production: true)` returns `ca-app-pub-3222893031015336/8843106337`, and `adUnitIdFor(AdPlatform.ios, AdType.banner, production: true)` returns the same. Existing getters `bannerAdUnitId` / `interstitialAdUnitId` / `rewardedAdUnitId` keep their signatures.

- [ ] **Step 1: Update the banner production values**

Edit `lib/add/ad_helper.dart` lines 61-68 (the two banner cases). Change only the `production` branch of each:

```dart
      case (AdPlatform.android, AdType.banner):
        return production
            ? 'ca-app-pub-3222893031015336/8843106337'
            : 'ca-app-pub-3940256099942544/6300978111';
      case (AdPlatform.ios, AdType.banner):
        return production
            ? 'ca-app-pub-3222893031015336/8843106337'
            : 'ca-app-pub-3940256099942544/2934735716';
```

Leave interstitial cases (lines 69-74) and rewarded cases (lines 75-82) exactly as they are.

- [ ] **Step 2: Verify the diff is banner-only**

Run: `git diff lib/add/ad_helper.dart`
Expected: only the two banner `production` string literals changed. Interstitial TODOs and rewarded IDs unchanged.

- [ ] **Step 3: Commit**

```bash
git add lib/add/ad_helper.dart
git commit -m "feat(ads): use new production banner ad unit IDs"
```

---

### Task 3: Update tests to assert new production banner IDs

**Files:**
- Modify: `test/ad_helper_test.dart:39-47`

**Interfaces:**
- Consumes: `AdHelper.adUnitIdFor` from Task 2 — same signature `(AdPlatform, AdType, {required bool production})`.
- Produces: regression coverage locking the new production banner IDs and the unchanged test IDs.

- [ ] **Step 1: Update the production banner assertions**

Edit `test/ad_helper_test.dart` lines 39-47. Change only the two banner expectations in the `production: true` test:

```dart
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.banner,
            production: true),
        'ca-app-pub-3222893031015336/8843106337',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.banner, production: true),
        'ca-app-pub-3222893031015336/8843106337',
      );
```

Leave every other assertion in the file (test-ID assertions, interstitial, rewarded, unsupported-platform) unchanged.

- [ ] **Step 2: Run the ad helper tests**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS — all 3 tests green.

- [ ] **Step 3: Commit**

```bash
git add test/ad_helper_test.dart
git commit -m "test(ads): assert new production banner ad unit IDs"
```

---

### Task 4: Full verification — analyze, tests, release config sanity

**Files:**
- Test: `test/ad_helper_test.dart` (already updated in Task 3)

**Interfaces:**
- Consumes: all changes from Tasks 1-3.
- Produces: evidence that nothing is broken and release builds resolve the new IDs.

- [ ] **Step 1: Run the analyzer**

Run: `flutter analyze`
Expected: No issues found.

- [ ] **Step 2: Run the full test suite**

Run: `flutter test`
Expected: ALL PASS. Pay attention to `test/ad_helper_test.dart`, `test/header_banner_ad_test.dart`, `test/scaled_banner_ad_test.dart`, `test/builder_ad_watches_test.dart` — banner tests run on the host VM where `bannerAdUnitId` throws inside existing try/catch, so widgets still render with no ad.

- [ ] **Step 3: Confirm release-mode ID resolution**

The `production` branch cannot be exercised under `flutter test` because `kReleaseMode` is `false` on the host VM. Instead, verify by inspection: `rg "3222893031015336" lib test android ios` should show the App ID (2 config matches), the banner production ID (2 in `ad_helper.dart`, 2 in `ad_helper_test.dart`), and no other files.

- [ ] **Step 4: Commit any plan/bookkeeping changes if needed**

No code changes expected in this task. If `flutter analyze` or the full test suite surfaced no issues, nothing to commit here.

## Self-Review

- **Spec coverage:** App ID in Android manifest (Task 1 Step 1) ✓; App ID in Info.plist (Task 1 Step 2) ✓; banner production IDs both platforms (Task 2) ✓; test IDs kept for debug/profile (Task 2 code shows unchanged test branch) ✓; interstitial/rewarded untouched (Task 2 Step 2 verification) ✓; test updates (Task 3) ✓; analyze + tests (Task 4) ✓; SDK init and release ad loading (Task 4 Step 3 + Global Constraints; init flow in `AdHelper.ensureInitialized` is untouched) ✓.
- **Placeholder scan:** No TBD/TODO placeholders; the only TODOs referenced are the pre-existing intentional interstitial ones that must remain.
- **Type consistency:** `adUnitIdFor` signature matches between Task 2 (implementation) and Task 3 (test). Getter names unchanged throughout.

## Non-Code Follow-up (out of scope)

- Confirm fill status in the AdMob dashboard for the new account's banner unit.
- Verify `app-ads.txt` for the new account domain.
- If AdMob requires distinct iOS banner units, add an iOS-specific production banner ID later.
- **Rewarded production IDs (lib/add/ad_helper.dart) still point at the OLD account (6138624088986178) and will NOT fill under the new App ID (3222893031015336) — this is the approved banner-only scope. Migrate the rewarded units to the new account as a discrete follow-up task once the user approves extending the scope.**
