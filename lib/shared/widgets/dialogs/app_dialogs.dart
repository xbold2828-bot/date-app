import 'package:dating_app/core/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

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
   static Future<bool?> premiumOrAdDialog({
    required BuildContext context,
    headingText = AppString.matchLimitTitle,
    descriptionText = AppString.matchLimitDescription,
    VoidCallback? onBuyPremium,
    VoidCallback? onWatchAd,
    String buyButtonText = AppString.buyPremium ,
    String watchAdButtonText = AppString.watchAd,
    IconData? iconData,
    String? vectorAsset,
    bool dismissible = false,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: dismissible,
      builder: (context) {
        return PremiumOrAdDialog(
          headingText: headingText,
          descriptionText: descriptionText,
          onBuyPremium: onBuyPremium??(){
            context.push(AppRoutes.buyPremium);
          },
          onWatchAd: onWatchAd ??(){},
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