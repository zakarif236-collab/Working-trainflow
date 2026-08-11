import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

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

  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Google test banner ad unit
      // Production: 'ca-app-pub-6138624088986178/4990989256'
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6138624088986178/1269723322';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android Google test ID
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS Google test ID
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // Google test rewarded ad unit
      // Production: 'ca-app-pub-6138624088986178/2840036851'
    } else if (Platform.isIOS) {
      return 'ca-app-pub-6138624088986178/7209425656';
    } else {
      throw UnsupportedError('Unsupported platform');
    }
  }
}
