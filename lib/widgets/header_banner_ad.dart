import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:my_app/add/ad_helper.dart';
import 'package:my_app/widgets/scaled_banner_ad.dart';

class HeaderBannerAd extends StatefulWidget {
  const HeaderBannerAd({super.key});

  @override
  State<HeaderBannerAd> createState() => _HeaderBannerAdState();
}

class _HeaderBannerAdState extends State<HeaderBannerAd> {
  static const int _maxAdLoadAttempts = 3;

  BannerAd? _bannerAd;
  int _loadAttempts = 0;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
    await AdHelper.ensureInitialized();
    if (!mounted || _loadAttempts >= _maxAdLoadAttempts) {
      return;
    }
    String adUnitId;
    try {
      adUnitId = AdHelper.bannerAdUnitId;
    } catch (_) {
      return;
    }

    late final BannerAd ad;
    ad = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad;
          });
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Banner ad failed to load: ${error.code} - ${error.message}');
          failedAd.dispose();
          _loadAttempts += 1;
          if (_loadAttempts < _maxAdLoadAttempts) {
            Future<void>.delayed(
              Duration(seconds: 5 * _loadAttempts),
              _loadBannerAd,
            );
          }
        },
      ),
    );

    try {
      await ad.load();
    } catch (_) {
      ad.dispose();
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _bannerAd;
    if (ad == null) {
      return const SizedBox.shrink();
    }
    return ScaledBannerAd(
      width: 320,
      height: 50,
      child: AdWidget(ad: ad),
    );
  }
}
