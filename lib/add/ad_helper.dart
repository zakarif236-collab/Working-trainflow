import 'dart:io';

class AdHelper {
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
