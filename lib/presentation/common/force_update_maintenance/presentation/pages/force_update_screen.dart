import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_string.dart';
import '../../../../../core/extensions/global_back_extension.dart';
import '../../../../../core/utils/app_snack_bar.dart';
import '../../../../../core/utils/utils.dart';
import '../../../widgets/system_state.dart';

/// Blocks a version the backend no longer supports, and sends the person to
/// the store for the one it does.
class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  Future<void> _launchAppStore() async {
    Uri storeUrl;
    if (Platform.isAndroid) {
      storeUrl = Uri.parse(
        "https://play.google.com/store/apps/details?id=${AppConstants.androidAppId}",
      );
    } else if (Platform.isIOS) {
      storeUrl = Uri.parse(
        "https://apps.apple.com/app/${AppConstants.iosAppId}",
      );
    } else {
      AppSnackBar.showErrorSnackBar(
        title: "Error",
        message: "Unsupported Platform",
      );
      return;
    }

    await openUrl(isExternal: true, url: storeUrl.toString());
  }

  @override
  Widget build(BuildContext context) {
    return SystemStateLayout(
      icon: Icons.system_update_rounded,
      title: AppString.forceUpdateTitle,
      message: AppString.forceUpdateSubTitle,
      actionLabel: AppString.updateNow,
      onAction: _launchAppStore,
    ).withGlobalBackHandler(context);
  }
}
