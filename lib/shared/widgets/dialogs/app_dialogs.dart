import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/static_assets/app_vectors.dart';
import 'all_dialogs/common_dialog.dart';
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
