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
  bool _disposed = false;

  Completer<bool>? _loadCompleter;

  @override
  RewardedAdState build() {
    final isPremium = ref.watch(isUserHavePremiumProvider);
    debugPrint('🐛 [RewardedAdController] build() — isPremium=$isPremium');

    _disposed = false;
    ref.onDispose(() {
      _disposed = true;
      _rewardedAd?.dispose();
      _rewardedAd = null;
    });

    if (isPremium) return const RewardedAdState();

    // Don't touch `state` synchronously inside build() — provider isn't
    // initialized until build() returns. Defer to a microtask.
    Future.microtask(_loadAd);

    return const RewardedAdState();
  }

  /// Kicks off a load if one isn't already running, and returns a future
  /// that completes with true/false once *this* load attempt resolves.
  Future<bool> _loadAd() {
    if (_disposed) return Future.value(false);

    if (state.isAdReady && _rewardedAd != null) {
      debugPrint('🐛 [RewardedAdController] _loadAd() — already have a ready ad, skipping load');
      return Future.value(true);
    }

    // A load is already in flight — piggyback on it instead of starting
    // a second one.
    if (_loadCompleter != null && !_loadCompleter!.isCompleted) {
      debugPrint('🐛 [RewardedAdController] _loadAd() — load already in flight, piggybacking');
      return _loadCompleter!.future;
    }

    debugPrint('🐛 [RewardedAdController] _loadAd() — starting RewardedAd.load');
    final completer = Completer<bool>();
    _loadCompleter = completer;
    state = state.copyWith(isLoading: true);

    RewardedAd.load(
      adUnitId: AdHelper.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('🐛 [RewardedAdController] onAdLoaded — ad ready');
          if (_disposed) {
            ad.dispose();
            if (!completer.isCompleted) completer.complete(false);
            return;
          }
          _rewardedAd = ad;
          state = state.copyWith(isLoading: false, isAdReady: true);
          if (!completer.isCompleted) completer.complete(true);
        },
        onAdFailedToLoad: (error) {
          debugPrint('🐛 [RewardedAdController] onAdFailedToLoad: $error');
          if (kDebugMode) print('Rewarded ad failed: $error');
          if (!_disposed) {
            state = state.copyWith(isLoading: false, isAdReady: false);
          }
          if (!completer.isCompleted) completer.complete(false);
        },
      ),
    );

    return completer.future;
  }

  Future<bool> showAdToUnlock(RewardedUnlockType type) async {
    final isPremium = ref.read(isUserHavePremiumProvider);
    debugPrint('🐛 [RewardedAdController] showAdToUnlock($type) — isUserHavePremiumProvider=$isPremium');

    if (isPremium) {
      debugPrint('🐛 [RewardedAdController] Premium bypass — returning true WITHOUT showing an ad. '
          'If you are testing as a non-premium user and see this line, the bug is that '
          'isUserHavePremiumProvider is incorrectly true — check where/when me() sets it.');
      return true;
    }

    if (state.isShowingAd) {
      debugPrint('🐛 [RewardedAdController] Already showing an ad — ignoring duplicate call');
      return false;
    }

    if (!state.isAdReady || _rewardedAd == null) {
      debugPrint('🐛 [RewardedAdController] No ad ready — awaiting _loadAd() (10s timeout)');
      // Wait for the (possibly already-in-flight) load instead of
      // failing instantly on the first tap. Time-boxed so the UI never
      // hangs forever if the network is bad.
      final loaded = await _loadAd().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          debugPrint('🐛 [RewardedAdController] _loadAd() timed out after 10s');
          return false;
        },
      );
      if (_disposed || !loaded || _rewardedAd == null) {
        debugPrint('🐛 [RewardedAdController] Bailing — disposed=$_disposed loaded=$loaded ad=${_rewardedAd != null}');
        return false;
      }
    }

    debugPrint('🐛 [RewardedAdController] Calling ad.show()');
    final ad = _rewardedAd!;
    final completer = Completer<bool>();
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        debugPrint('🐛 [RewardedAdController] onAdShowedFullScreenContent');
        if (!_disposed) state = state.copyWith(isShowingAd: true);
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('🐛 [RewardedAdController] onAdDismissedFullScreenContent — earnedReward=$earnedReward');
        ad.dispose();
        _rewardedAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false, isAdReady: false);
          _loadAd();
        }
        if (!completer.isCompleted) completer.complete(earnedReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('🐛 [RewardedAdController] onAdFailedToShowFullScreenContent: $error');
        ad.dispose();
        _rewardedAd = null;
        if (!_disposed) {
          state = state.copyWith(isShowingAd: false, isAdReady: false);
          _loadAd();
        }
        if (!completer.isCompleted) completer.complete(false);
      },
    );

    ad.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('🐛 [RewardedAdController] onUserEarnedReward fired — reward=${reward.amount} ${reward.type}');
        earnedReward = true;
      },
    );

    return completer.future;
  }
}

final rewardedAdControllerProvider =
NotifierProvider<RewardedAdController, RewardedAdState>(
  RewardedAdController.new,
);