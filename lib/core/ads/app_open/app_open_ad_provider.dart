import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../providers/is_user_have_premium_provider.dart';
import '../ad_helper.dart';
import 'app_open_ad_state.dart';

const Duration kMinGapBetweenAppOpenAds = Duration(minutes: 15);
const Duration kAppOpenAdMaxCacheAge = Duration(hours: 4);
const String _kLastShownPrefsKey = 'app_open_ad_last_shown_at';

class AppOpenAdController extends Notifier<AppOpenAdState>
    with WidgetsBindingObserver {
  AppOpenAd? _appOpenAd;
  DateTime? _adLoadedAt;
  DateTime? _lastShownAt;
  bool _disposed = false;

  @override
  AppOpenAdState build() {
    // final isPremium = ref.watch(isUserHavePremiumProvider);

    _disposed = false;
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() {
      _disposed = true;
      WidgetsBinding.instance.removeObserver(this);
      _appOpenAd?.dispose();
      _appOpenAd = null;
    });

    // if (isPremium) return const AppOpenAdState();

    // Don't touch `state` synchronously inside build() — the provider
    // isn't initialized until build() returns. Defer to a microtask.
    Future.microtask(() {
      _restoreLastShownTime();
      _loadAd();
    });

    return const AppOpenAdState();
  }

  Future<void> _restoreLastShownTime() async {
    if (_disposed) return;
    final prefs = await SharedPreferences.getInstance();
    if (_disposed) return;
    final millis = prefs.getInt(_kLastShownPrefsKey);
    if (millis != null) {
      _lastShownAt = DateTime.fromMillisecondsSinceEpoch(millis);
    }
  }

  Future<void> _persistLastShownTime(DateTime time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kLastShownPrefsKey, time.millisecondsSinceEpoch);
  }

  bool get _isAdFresh {
    if (_adLoadedAt == null) return false;
    return DateTime.now().difference(_adLoadedAt!) < kAppOpenAdMaxCacheAge;
  }

  bool get _isAdAvailable => _appOpenAd != null && _isAdFresh;

  bool get _cooldownElapsed {
    if (_lastShownAt == null) return true;
    return DateTime.now().difference(_lastShownAt!) >=
        kMinGapBetweenAppOpenAds;
  }

  void _loadAd() {
    if (_disposed) return;
    if (state.isLoadingAd || _isAdAvailable) return;

    state = state.copyWith(isLoadingAd: true);

    AppOpenAd.load(
      adUnitId: AdHelper.appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          if (_disposed) {
            ad.dispose();
            return;
          }
          _appOpenAd = ad;
          _adLoadedAt = DateTime.now();
          state = state.copyWith(isLoadingAd: false);
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) print('App open ad failed: $error');
          if (_disposed) return;
          state = state.copyWith(isLoadingAd: false);
        },
      ),
    );
  }

  void showAdIfEligible() {
    if (_disposed) return;
    if (ref.read(isUserHavePremiumProvider)) return;
    if (state.isShowingAd || !_cooldownElapsed) return;

    if (!_isAdAvailable) {
      _loadAd();
      return;
    }

    final ad = _appOpenAd!;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        if (!_disposed) state = state.copyWith(isShowingAd: true);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _appOpenAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false);
          _loadAd();
        }
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _appOpenAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false);
          _loadAd();
        }
      },
    );

    _lastShownAt = DateTime.now();
    _persistLastShownTime(_lastShownAt!);
    ad.show();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState appState) {
    if (appState == AppLifecycleState.resumed) showAdIfEligible();
  }
}

final appOpenAdControllerProvider =
NotifierProvider<AppOpenAdController, AppOpenAdState>(
  AppOpenAdController.new,
);