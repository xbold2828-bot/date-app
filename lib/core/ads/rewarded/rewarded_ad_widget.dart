import 'package:dating_app/core/ads/rewarded/rewarded_ad_provider.dart';
import 'package:dating_app/core/ads/rewarded/rewarded_unlock_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';


/// Wraps the reward-ad flow so callers don't touch the controller directly.
///
/// Usage:
/// ```dart
/// RewardedAdWidget(
///   unlockType: RewardedUnlockType.seeWhoLikedYou,
///   onRewardEarned: () => unlockFeature(),
///   onFailed: () => showSnack('Ad not ready, try again'),
///   builder: (context, isLoading, isReady, onTap) {
///     return ElevatedButton(
///       onPressed: isLoading ? null : onTap,
///       child: isLoading
///           ? const SizedBox(
///               width: 16, height: 16,
///               child: CircularProgressIndicator(strokeWidth: 2),
///             )
///           : const Text('Watch ad to unlock'),
///     );
///   },
/// )
/// ```
class RewardedAdWidget extends ConsumerStatefulWidget {
  const RewardedAdWidget({
    super.key,
    required this.unlockType,
    required this.builder,
    required this.onRewardEarned,
    this.onFailed,
  });

  final RewardedUnlockType unlockType;

  /// Build your own tap target. [isLoading] is true while an ad is being
  /// fetched or is currently on screen. [isReady] tells you whether an ad
  /// is cached and can be shown immediately on [onTap].
  final Widget Function(
      BuildContext context,
      bool isLoading,
      bool isReady,
      VoidCallback onTap,
      ) builder;

  /// Called when the user watches the ad to completion and earns the reward.
  final VoidCallback onRewardEarned;

  /// Called when the ad fails to show, or the user dismisses it early
  /// without earning the reward.
  final VoidCallback? onFailed;

  @override
  ConsumerState<RewardedAdWidget> createState() => _RewardedAdWidgetState();
}

class _RewardedAdWidgetState extends ConsumerState<RewardedAdWidget> {
  bool _isRequesting = false;

  Future<void> _handleTap() async {
    if (_isRequesting) return;
    setState(() => _isRequesting = true);

    final earned = await ref
        .read(rewardedAdControllerProvider.notifier)
        .showAdToUnlock(widget.unlockType);

    if (!mounted) return;
    setState(() => _isRequesting = false);

    if (earned) {
      widget.onRewardEarned();
    } else {
      widget.onFailed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rewardedAdControllerProvider);
    final isLoading = _isRequesting || state.isLoading || state.isShowingAd;

    return widget.builder(context, isLoading, state.isAdReady, _handleTap);
  }
}