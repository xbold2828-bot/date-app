import 'package:flutter/material.dart';

import '../../../../presentation/common/widgets/radius_dialog.dart';

/// A confirmation in the app's alert style — see [RadiusAlert].
///
/// Pops `true` before running [onTap], so a caller awaiting the dialog and a
/// caller passing a callback both work.
class CommonDialog extends StatelessWidget {
  final String headingText;
  final bool isShowTwoButtons;
  final String? descriptionText;
  final String buttonText;
  final VoidCallback onTap;

  /// Paints the confirm row red — for actions that lose something.
  final bool destructive;

  const CommonDialog({
    super.key,
    required this.isShowTwoButtons,
    required this.headingText,
    required this.buttonText,
    required this.onTap,
    this.descriptionText,
    this.destructive = false,
  });

  @override
  Widget build(BuildContext context) {
    return RadiusAlert(
      title: headingText,
      message: descriptionText,
      actions: [
        RadiusAlertAction(
          label: buttonText,
          tone: destructive
              ? RadiusAlertTone.destructive
              : RadiusAlertTone.primary,
          onPressed: () {
            Navigator.of(context).pop(true);
            onTap();
          },
        ),
        if (isShowTwoButtons)
          RadiusAlertAction(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
      ],
    );
  }
}
