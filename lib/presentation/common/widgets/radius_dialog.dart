import 'package:flutter/material.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme/app_colors.dart';

/// How an action at the foot of a [RadiusAlert] reads.
enum RadiusAlertTone {
  /// The way out — "Cancel", "Not now". Regular weight, ink.
  normal,

  /// The thing the alert is asking you to do. Bold, accent blue.
  primary,

  /// An action that loses something — sign out, delete, unblock. Bold, red.
  destructive,

  /// An action that costs money. Bold, premium purple, and nowhere else.
  premium,
}

/// One full-width row at the foot of a [RadiusAlert].
class RadiusAlertAction {
  const RadiusAlertAction({
    required this.label,
    required this.onPressed,
    this.tone = RadiusAlertTone.normal,
    this.isLoading = false,
  });

  final String label;

  /// Null disables the row.
  final VoidCallback? onPressed;
  final RadiusAlertTone tone;

  /// Swaps the label for a small spinner beside it and swallows presses.
  final bool isLoading;
}

/// The app's alert: a short title, a line or two saying what happens, and
/// the choices as stacked rows split by hairlines — the confirm on top, the
/// way out at the bottom.
///
/// No icon badge over the title and no pair of filled buttons. The words are
/// the content; a red "Sign out" row says more than a blue circle with a
/// door in it ever did.
class RadiusAlert extends StatelessWidget {
  const RadiusAlert({
    super.key,
    required this.title,
    required this.actions,
    this.message,
    this.child,
  });

  final String title;
  final String? message;

  /// Sits under the message — a text field, usually.
  final Widget? child;

  final List<RadiusAlertAction> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 36, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: AppColors.isDark
            ? BorderSide(color: AppColors.inputBorder)
            : BorderSide.none,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The words scroll if a short screen or a large text size runs
            // out of room; the actions never do.
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                child: Column(
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.title.copyWith(fontSize: 20),
                      ),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMuted,
                      ),
                    ],
                    if (child != null) ...[const SizedBox(height: 18), child!],
                  ],
                ),
              ),
            ),
            for (final action in actions) ...[
              Divider(height: 1, thickness: 1, color: AppColors.inputBorder),
              _ActionRow(action: action),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.action});

  final RadiusAlertAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onPressed != null && !action.isLoading;

    final Color color = switch (action.tone) {
      RadiusAlertTone.normal => AppColors.textDark,
      RadiusAlertTone.primary => AppColors.primary,
      RadiusAlertTone.destructive => AppColors.danger,
      RadiusAlertTone.premium => AppColors.premium,
    };
    final quiet = action.tone == RadiusAlertTone.normal;

    final label = Text(
      action.label,
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.body.copyWith(
        fontSize: 15.5,
        height: 1.3,
        color: enabled ? color : AppColors.textGrey,
        fontWeight: quiet ? FontWeight.w500 : FontWeight.w700,
        fontVariations: [FontVariation('wght', quiet ? 500 : 700)],
      ),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: action.isLoading ? '${action.label}, working' : action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: enabled ? action.onPressed : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Center(
              child: action.isLoading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(child: label),
                      ],
                    )
                  : label,
            ),
          ),
        ),
      ),
    );
  }
}

/// Asks a yes-or-no question and answers it: true only when the confirm row
/// was tapped. Dismissing by the scrim or the back gesture counts as no.
Future<bool> showRadiusConfirm(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  String? message,
  String cancelLabel = 'Cancel',
  bool destructive = false,
  bool barrierDismissible = true,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: AppColors.scrim,
    builder: (dialogContext) => RadiusAlert(
      title: title,
      message: message,
      actions: [
        RadiusAlertAction(
          label: confirmLabel,
          tone: destructive
              ? RadiusAlertTone.destructive
              : RadiusAlertTone.primary,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        RadiusAlertAction(
          label: cancelLabel,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
