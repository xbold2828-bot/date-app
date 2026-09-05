import 'package:dating_app/core/router/app_router.dart';
import 'package:dating_app/providers/is_user_have_premium_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/ads/rewarded/rewarded_unlock_type.dart';
import '../../../core/constants/app_string.dart';
import '../../../core/constants/static_assets/app_vectors.dart';
import 'all_dialogs/common_dialog.dart';
import 'all_dialogs/premium_or_ad_dialog.dart';
import 'all_dialogs/reason_dialog.dart';

abstract final class AppDialogs {
  static Future<bool?> commonDialog({
    required BuildContext context,
    required String headingText,
    required String descriptionText,
    required String buttonText,
    VoidCallback? onTap,
    IconData? iconData,
    String? vectorLogo,
    String? imageLogo,
    bool dismissible = false,
    bool isShowTwoButtons = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) {
        return CommonDialog(
          isShowTwoButtons: isShowTwoButtons,
          headingText: headingText,
          descriptionText: descriptionText,
          buttonText: buttonText,
          onTap: onTap ?? () {},
          vectorLogo: vectorLogo,
          imageLogo: imageLogo,
          iconData: iconData,
        );
      },
    );
  }

  static Future<String?> reasonDialog({
    required BuildContext context,
    required String headingText,
    required String descriptionText,
    required String buttonText,
    String hintText = 'Type your reason here...',
    IconData? iconData,
    bool dismissible = false,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) {
        return ReasonDialog(
          headingText: headingText,
          descriptionText: descriptionText,
          buttonText: buttonText,
          hintText: hintText,
          iconData: iconData,
        );
      },
    );
  }

  /// The "buy Premium OR watch an ad" paywall dialog — heading, description,
  /// both button labels, both callbacks, and the badge icon are all
  /// dynamic, plus a close (✕) icon in the top corner.
  static Future<void> premiumOrAdDialog({
    required BuildContext context,
    required RewardedUnlockType unlockType,
    required WidgetRef ref,
    headingText = AppString.matchLimitTitle,
    descriptionText = AppString.matchLimitDescription,
    VoidCallback? onBuyPremium,
    VoidCallback? onAdEarned,
    String buyButtonText = AppString.buyPremium,
    String watchAdButtonText = AppString.watchAd,
    IconData? iconData,
    String? vectorAsset,
    bool dismissible = false,
  }) async {
    // Premium users skip the paywall entirely — treat it as an
    // already-earned unlock.
    if (ref.read(isUserHavePremiumProvider)) {
      onAdEarned?.call();
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) {
        return PremiumOrAdDialog(
          headingText: headingText,
          descriptionText: descriptionText,
          unlockType: unlockType,
          onBuyPremium: onBuyPremium ?? () => context.push(AppRoutes.buyPremium),
          onAdEarned: onAdEarned,
          buyButtonText: buyButtonText,
          watchAdButtonText: watchAdButtonText,
          iconData: iconData,
          vectorAsset: vectorAsset,
          dismissible: dismissible,
        );
      },
    );
  }

  static Future<void> exitDialog(BuildContext context) {
    return commonDialog(
      context: context,
      isShowTwoButtons: true,
      vectorLogo: AppVectors.exit,
      headingText: "Exit",
      descriptionText: "Are you sure you want to exit?",
      buttonText: "Confirm",
      onTap: () {
        SystemNavigator.pop();
      },
    );
  }
}