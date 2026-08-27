import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../shared/widgets/dialogs/app_dialogs.dart';

extension BackHandlerExtension on Widget {
  Widget withGlobalBackHandler(BuildContext context) {
    /// ✅ Apply ONLY on Android & iOS
    final isMobilePlatform =
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;

    if (!isMobilePlatform) {
      return this;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;

        final navigator = Navigator.of(context);

        /// ✅ Normal back
        if (navigator.canPop()) {
          navigator.pop();
        } else {
          AppDialogs.exitDialog(context);
        }
      },
      child: this,
    );
  }
}
