import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ads/rewarded/rewarded_ad_provider.dart';
import '../../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../../core/logger/app_logger.dart';
import '../../../../core/utils/app_snack_bar.dart';
import '../../../../presentation/common/widgets/radius_dialog.dart';

/// "Get Premium, or watch a short ad" — the choice offered whenever a free
/// allowance runs out. An alert with three rows: the purchase in premium
/// purple, the ad in accent blue, and the way out.
class PremiumOrAdDialog extends ConsumerStatefulWidget {
  final String headingText;
  final String descriptionText;
  final String buyButtonText;
  final String watchAdButtonText;
  final RewardedUnlockType unlockType;
  final VoidCallback onBuyPremium;
  final VoidCallback? onAdEarned;
  final bool dismissible;

  const PremiumOrAdDialog({
    super.key,
    required this.headingText,
    required this.descriptionText,
    required this.onBuyPremium,
    required this.unlockType,
    this.onAdEarned,
    this.buyButtonText = 'Get Premium',
    this.watchAdButtonText = 'Watch a short ad',
    this.dismissible = false,
  });

  @override
  ConsumerState<PremiumOrAdDialog> createState() => _PremiumOrAdDialogState();
}

class _PremiumOrAdDialogState extends ConsumerState<PremiumOrAdDialog> {
  bool _loadingAd = false;

  Future<void> _handleWatchAd() async {
    AppLogger.d('[PremiumOrAdDialog] Watch Ad tapped, unlockType=${widget.unlockType}');

    if (_loadingAd) {
      AppLogger.d('[PremiumOrAdDialog] Ignored tap — already loading an ad');
      return;
    }

    setState(() => _loadingAd = true);
    AppLogger.d('[PremiumOrAdDialog] _loadingAd set to true');

    bool earned = false;
    String? failureMessage;

    AppLogger.d('[PremiumOrAdDialog] Calling rewardedAdControllerProvider.showAdToUnlock(${widget.unlockType})');
    try {
      earned = await ref
          .read(rewardedAdControllerProvider.notifier)
          .showAdToUnlock(widget.unlockType);
      AppLogger.d('[PremiumOrAdDialog] showAdToUnlock resolved: earned=$earned');
    } catch (e, st) {
      AppLogger.e('[PremiumOrAdDialog] showAdToUnlock threw', error: e, stackTrace: st);
      failureMessage = 'Ad not available right now. Try again shortly.';
    }

    AppLogger.d('[PremiumOrAdDialog] After await — mounted=$mounted, context.mounted=${context.mounted}');
    if (!mounted || !context.mounted) {
      AppLogger.d('[PremiumOrAdDialog] Bailing out — widget unmounted');
      return;
    }

    // Trust boundary: this dialog only grants a reward when
    // showAdToUnlock() resolves true. If a reward is being granted
    // without the ad visibly playing, the defect is inside
    // rewardedAdControllerProvider.showAdToUnlock() — not here. Check
    // that it only resolves true from an actual onUserEarnedReward
    // (or SDK-equivalent) callback, not from onAdLoaded / a cached
    // instance / a dev stub.
    if (earned) {
      // IMPORTANT: pop the dialog's own route FIRST, then invoke the
      // caller's callback. If onAdEarned() pushes a new route (as
      // _MutualRow._openChat does) before we pop, our pop below ends up
      // popping that freshly-pushed route instead of the dialog,
      // which immediately reverses the navigation the caller just did.
      AppLogger.d('[PremiumOrAdDialog] earned=true — popping(true) then calling onAdEarned');
      context.pop(true);
      widget.onAdEarned?.call();
      return;
    }

    AppLogger.d('[PremiumOrAdDialog] earned=false — resetting _loadingAd, showing snackbar: ${failureMessage ?? 'default message'}');
    setState(() => _loadingAd = false);
    AppSnackBar.showWarningSnackBar(
      message: failureMessage ??
          'You need to watch the full ad to unlock this.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return RadiusAlert(
      title: widget.headingText,
      message: widget.descriptionText,
      actions: [
        RadiusAlertAction(
          label: widget.buyButtonText,
          tone: RadiusAlertTone.premium,
          onPressed: _loadingAd
              ? null
              : () {
                  AppLogger.d('[PremiumOrAdDialog] Buy Premium tapped — popping(false)');
                  context.pop(false);
                  widget.onBuyPremium();
                },
        ),
        RadiusAlertAction(
          label: _loadingAd ? 'Loading the ad' : widget.watchAdButtonText,
          tone: RadiusAlertTone.primary,
          isLoading: _loadingAd,
          onPressed: _handleWatchAd,
        ),
        // Always live, even mid-load: an ad that never arrives must not
        // leave the person stuck behind a dialog they cannot close.
        RadiusAlertAction(
          label: 'Not now',
          onPressed: () {
            AppLogger.d('[PremiumOrAdDialog] Not now tapped — popping(false)');
            context.pop(false);
          },
        ),
      ],
    );
  }
}