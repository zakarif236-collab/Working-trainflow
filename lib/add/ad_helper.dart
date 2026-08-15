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
            ? 'ca-app-pub-3222893031015336/8843106337'
            : 'ca-app-pub-3940256099942544/6300978111';
      case (AdPlatform.ios, AdType.banner):
        return production
            ? 'ca-app-pub-3222893031015336/8843106337'
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
