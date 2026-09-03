import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../../../providers/is_user_have_premium_provider.dart';
import '../ad_helper.dart';
import 'rewarded_ad_state.dart';
import 'rewarded_unlock_type.dart';

class RewardedAdController extends Notifier<RewardedAdState> {
  RewardedAd? _rewardedAd;

  @override
  RewardedAdState build() {
    final isPremium = ref.watch(isUserHavePremiumProvider);

    ref.onDispose(() {
      _rewardedAd?.dispose();
      _rewardedAd = null;
    });

    if (isPremium) return const RewardedAdState();

    _loadAd();
    return const RewardedAdState();
  }

  void _loadAd() {
    if (state.isLoading || state.isAdReady) return;
    state = state.copyWith(isLoading: true);

    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          state = state.copyWith(isLoading: false, isAdReady: true);
        },
        onAdFailedToLoad: (error) {
          if (kDebugMode) print('Rewarded ad failed: $error');
          state = state.copyWith(isLoading: false, isAdReady: false);
        },
      ),
    );
  }

  Future<bool> showAdToUnlock(RewardedUnlockType type) async {
    if (ref.read(isUserHavePremiumProvider)) return true;
    if (state.isShowingAd) return false;

    if (!state.isAdReady || _rewardedAd == null) {
      _loadAd();
      return false;
    }

    final ad = _rewardedAd!;
    final completer = Completer<bool>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        state = state.copyWith(isShowingAd: true);
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        state = state.copyWith(isShowingAd: false, isAdReady: false);
        _loadAd();
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        state = state.copyWith(isShowingAd: false, isAdReady: false);
        _loadAd();
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) => earnedReward = true,
    );

    return completer.future;
  }
}

final rewardedAdControllerProvider =
NotifierProvider<RewardedAdController, RewardedAdState>(
  RewardedAdController.new,
);