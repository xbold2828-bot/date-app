import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

abstract final class AdHelper {
  static String get bannerAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/6300978111';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    throw UnsupportedError('Unsupported platform');
  }

  static String get appOpenAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/9257395921';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/5575463023';
    throw UnsupportedError('Unsupported platform');
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) return 'ca-app-pub-3940256099942544/5224354917';
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    throw UnsupportedError('Unsupported platform');
  }

  static BannerAd createBannerAd({
    AdSize size = AdSize.banner,
    void Function(Ad ad)? onLoaded,
    void Function(Ad ad, LoadAdError error)? onFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (kDebugMode) print('Banner ad loaded');
          onLoaded?.call(ad);
        },
        onAdFailedToLoad: (ad, error) {
          if (kDebugMode) print('Banner ad failed: $error');
          ad.dispose();
          onFailedToLoad?.call(ad, error);
        },
      ),
    )..load();
  }
}