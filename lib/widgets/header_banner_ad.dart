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
  BannerAd? _bannerAd;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  Future<void> _loadBannerAd() async {
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
          if (mounted) {
            setState(() {
              _bannerAd = ad;
            });
          }
        },
        onAdFailedToLoad: (failedAd, error) {
          debugPrint('Banner ad failed to load: ${error.code} - ${error.message}');
          failedAd.dispose();
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
