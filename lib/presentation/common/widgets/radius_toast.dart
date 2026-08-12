import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// Confirms that something just happened, then gets out of the way.
///
/// A dark pill on the cream ground. Use it for the outcome of an action the
/// person took — "Filters applied", "Blocked". Not for errors that need a
/// decision, and not for anything they must read before continuing.
///
/// Keep the message in the same words as the control that triggered it: a
/// button saying "Block" produces "Blocked", never "Report submitted".
void showRadiusToast(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyStrong.copyWith(
            color: AppColors.white,
            fontSize: 13.5,
          ),
        ),
        backgroundColor: AppColors.textDark,
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        duration: const Duration(milliseconds: 2400),
        // Sits clear of the bottom nav rather than covering it.
        margin: const EdgeInsets.fromLTRB(24, 0, 24, 96),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
}
