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
        'ca-app-pub-3222893031015336/8843106337',
      );
      expect(
        AdHelper.adUnitIdFor(AdPlatform.ios, AdType.banner, production: true),
        'ca-app-pub-3222893031015336/8843106337',
      );
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
