# AdMob Debug/Release Ad Unit IDs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AdMob ad unit IDs resolve to Google test IDs in debug/profile builds and production IDs in release builds, on both Android and iOS.

**Architecture:** `AdHelper` (lib/add/ad_helper.dart) is the single source of truth for ad unit IDs. The three public getters detect the current platform and delegate to a pure, testable resolver `adUnitIdFor(platform, type, {required bool production})` that returns the correct ID. The `production` flag is bound to Flutter's compile-time `kReleaseMode`, so release AABs automatically request live inventory and debug builds stay on test IDs.

**Tech Stack:** Flutter / Dart 3, `google_mobile_ads: ^9.0.0`, `flutter_test`.

## Global Constraints

- Debug/profile builds MUST use Google test ad unit IDs on both platforms.
- Release builds MUST use production IDs for banner and rewarded on both platforms.
- Interstitials remain on Google test IDs on both platforms in both modes, marked with a `// TODO(ads): add production interstitial IDs` comment.
- Non-Android/iOS platforms MUST throw `UnsupportedError`.
- Existing ad call sites (header_banner_ad.dart, home_page.dart, workout_builder_page.dart) MUST NOT change; they already route through `AdHelper`.
- ID matrix (verbatim from spec):
  - Android banner: test `ca-app-pub-3940256099942544/6300978111`, prod `ca-app-pub-6138624088986178/4990989256`
  - iOS banner: test `ca-app-pub-3940256099942544/2934735716`, prod `ca-app-pub-6138624088986178/1269723322`
  - Android interstitial: test `ca-app-pub-3940256099942544/1033173712` (both modes)
  - iOS interstitial: test `ca-app-pub-3940256099942544/4411468910` (both modes)
  - Android rewarded: test `ca-app-pub-3940256099942544/5224354917`, prod `ca-app-pub-6138624088986178/2840036851`
  - iOS rewarded: test `ca-app-pub-3940256099942544/2178118514`, prod `ca-app-pub-6138624088986178/7209425656`

---

### Task 1: Add testable AdMob ID resolution with debug/release switching

**Files:**
- Create: `test/ad_helper_test.dart`
- Modify: `lib/add/ad_helper.dart`

**Interfaces:**
- Consumes: nothing (start of chain; replaces the hardcoded test IDs in `lib/add/ad_helper.dart:30-60`)
- Produces (what later consumers rely on — the public getters keep their existing signatures, so no caller changes are needed):
  - `AdHelper.bannerAdUnitId` / `AdHelper.interstitialAdUnitId` / `AdHelper.rewardedAdUnitId` — existing `String` getters, unchanged signatures
  - `AdHelper.adUnitIdFor(AdPlatform platform, AdType type, {required bool production})` — pure resolver returning the `String` ad unit ID
  - `enum AdPlatform { android, ios }`
  - `enum AdType { banner, interstitial, rewarded }`

- [ ] **Step 1: Write the failing test**

Create `test/ad_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:my_app/add/ad_helper.dart';

void main() {
  group('AdHelper.adUnitIdFor', () {
    test('uses Google test IDs when production is false', () {
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.banner,
            production: false),
        'ca-app-pub-3940256099942544/6300978111',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.banner, production: false),
        'ca-app-pub-3940256099942544/2934735716',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.interstitial,
            production: false),
        'ca-app-pub-3940256099942544/1033173712',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.interstitial,
            production: false),
        'ca-app-pub-3940256099942544/4411468910',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.rewarded,
            production: false),
        'ca-app-pub-3940256099942544/5224354917',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.rewarded,
            production: false),
        'ca-app-pub-3940256099942544/2178118514',
      );
    });

    test('uses production IDs when production is true', () {
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.banner,
            production: true),
        'ca-app-pub-6138624088986178/4990989256',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.banner, production: true),
        'ca-app-pub-6138624088986178/1269723322',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.interstitial,
            production: true),
        'ca-app-pub-3940256099942544/1033173712',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.interstitial,
            production: true),
        'ca-app-pub-3940256099942544/4411468910',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.android, AdType.rewarded,
            production: true),
        'ca-app-pub-6138624088986178/2840036851',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.rewarded,
            production: true),
        'ca-app-pub-6138624088986178/7209425656',
      );
    });

    test('public getters throw UnsupportedError on unsupported platforms', () {
      // flutter test runs on the host VM; on Windows/Linux/macOS hosts neither
      // Platform.isAndroid nor Platform.isIOS is true, so all getters throw.
      expect(() => AdHelper.bannerAdUnitId, throwsUnsupportedError);
      expect(() => AdHelper.interstitialAdUnitId, throwsUnsupportedError);
      expect(() => AdHelper.rewardedAdUnitId, throwsUnsupportedError);
    });
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ad_helper_test.dart`
Expected: FAIL — compile error, `AdPlatform`, `AdType`, and `AdHelper.adUnitIdFor` are not defined.

- [ ] **Step 3: Implement the ad unit ID resolution**

Replace the entire contents of `lib/add/ad_helper.dart` with:

```dart
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

enum AdPlatform { android, ios }

enum AdType { banner, interstitial, rewarded }

class AdHelper {
  static Future<void>? _initialization;

  /// Ensures the Mobile Ads SDK is initialized before any ad is loaded.
  ///
  /// Safe to call from anywhere and as many times as needed: the underlying
  /// initialization Future is memoized so all callers share one initialization.
  /// On unsupported platforms this resolves immediately without doing anything.
  static Future<void> ensureInitialized() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return Future<void>.value();
    }
    return _initialization ??= _initialize();
  }

  static Future<void> _initialize() async {
    try {
      await MobileAds.instance.initialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      _initialization = null;
      debugPrint('[AdHelper] AdMob initialization failed: $e');
    }
  }

  static String get bannerAdUnitId => _forCurrentPlatform(AdType.banner);

  static String get interstitialAdUnitId =>
      _forCurrentPlatform(AdType.interstitial);

  static String get rewardedAdUnitId => _forCurrentPlatform(AdType.rewarded);

  static String _forCurrentPlatform(AdType type) {
    if (Platform.isAndroid) {
      return adUnitIdFor(AdPlatform.android, type, production: kReleaseMode);
    }
    if (Platform.isIOS) {
      return adUnitIdFor(AdPlatform.ios, type, production: kReleaseMode);
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Resolves the ad unit ID for a platform/type/mode combination.
  ///
  /// [production] is `kReleaseMode` in the public getters; when `false` the
  /// Google test IDs are returned so debug builds never hit live inventory.
  static String adUnitIdFor(
    AdPlatform platform,
    AdType type, {
    required bool production,
  }) {
    switch ((platform, type)) {
      case (AdPlatform.android, AdType.banner):
        return production
            ? 'ca-app-pub-6138624088986178/4990989256'
            : 'ca-app-pub-3940256099942544/6300978111';
      case (AdPlatform.ios, AdType.banner):
        return production
            ? 'ca-app-pub-6138624088986178/1269723322'
            : 'ca-app-pub-3940256099942544/2934735716';
      case (AdPlatform.android, AdType.interstitial):
        // TODO(ads): add production interstitial IDs
        return 'ca-app-pub-3940256099942544/1033173712';
      case (AdPlatform.ios, AdType.interstitial):
        // TODO(ads): add production interstitial IDs
        return 'ca-app-pub-3940256099942544/4411468910';
      case (AdPlatform.android, AdType.rewarded):
        return production
            ? 'ca-app-pub-6138624088986178/2840036851'
            : 'ca-app-pub-3940256099942544/5224354917';
      case (AdPlatform.ios, AdType.rewarded):
        return production
            ? 'ca-app-pub-6138624088986178/7209425656'
            : 'ca-app-pub-3940256099942544/2178118514';
    }
  }
}
```

- [ ] **Step 4: Run the new test to verify it passes**

Run: `flutter test test/ad_helper_test.dart`
Expected: PASS — all 3 tests green (the unsupported-platform test passes because the host is Windows; if run on Android/iOS it would be skipped as inapplicable, but CI/desktop hosts always throw).

- [ ] **Step 5: Run the full test suite and analyzer**

Run: `flutter test`
Expected: PASS — including the existing `header_banner_ad_test.dart` (on the host VM, `bannerAdUnitId` throws inside `_loadBannerAd`'s existing try/catch, so the widget still renders nothing).

Run: `flutter analyze`
Expected: No issues.

- [ ] **Step 6: Commit**

```bash
git add lib/add/ad_helper.dart test/ad_helper_test.dart
git commit -m "feat(ads): use production ad unit IDs in release, test IDs in debug"
```

## Self-Review

- **Spec coverage:** Debug=test IDs (Task 1 test + resolver) ✓; release=production banner/rewarded both platforms ✓; interstitials stay test with TODO ✓; unsupported platform throws ✓; call sites unchanged ✓.
- **Placeholder scan:** No TBD/TODO placeholders — the only TODO is the intentional interstitial follow-up comment required by the spec.
- **Type consistency:** `AdPlatform`/`AdType`/`adUnitIdFor` defined in Task 1 Step 3 and used identically in the Step 1 test; public getters keep their existing names/signatures.

## Non-Code Follow-up (out of scope)

- Host `app-ads.txt` so AdMob doesn't block serving.
- Confirm fill status in the AdMob dashboard once live.
- Add production interstitial IDs (wired via the `// TODO(ads):` comments above).
