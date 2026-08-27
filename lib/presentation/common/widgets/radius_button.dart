import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// What a button is for, which determines how it looks.
enum RadiusButtonKind {
  /// The one thing this screen wants you to do.
  primary,

  /// A real alternative sitting next to a [primary].
  ghost,

  /// Buys something. Premium purple appears here and nowhere else — if it shows up on a
  /// button that costs nothing, it stops meaning "this costs money".
  premium,
}

/// The app's button.
///
/// Full-width by default, because nearly every use is a footer action.
///
/// ## Give it an unbounded height
///
/// It ends in a [Container] with an alignment, and such a Container expands to
/// fill *bounded* constraints rather than wrapping its child. Inside a [Column]
/// or a [ListView] — where every call site here lives — the incoming height is
/// unbounded and it settles at its 54px minimum. Put it somewhere with a
/// bounded height and it takes all of it: dropped straight into a
/// `Scaffold.bottomNavigationBar`, which offers the height of the whole
/// screen, it became a full-screen slab of accent blue over the page behind it.
/// Wrap it in a `Column(mainAxisSize: MainAxisSize.min)` in those slots.
class RadiusButton extends StatelessWidget {
  const RadiusButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = RadiusButtonKind.primary,
    this.icon,
    this.isLoading = false,
    this.expand = true,
  });

  final String label;

  /// Null disables the button. During [isLoading] the press is swallowed so a
  /// double-tap cannot fire the action twice.
  final VoidCallback? onPressed;

  final RadiusButtonKind kind;
  final IconData? icon;
  final bool isLoading;

  /// False lets the button size to its label, for side-by-side rows.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;

    final Color foreground = switch (kind) {
      RadiusButtonKind.primary || RadiusButtonKind.premium => AppColors.onAccent,
      RadiusButtonKind.ghost => AppColors.textDark,
    };

    final content = isLoading
        ? SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: foreground,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: foreground),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.button.copyWith(
                    color: enabled ? foreground : AppColors.textGrey,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: true,
      enabled: enabled,
      label: isLoading ? '$label, working' : label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          // The premium variant is a gradient, which no Material colour can
          // express — so the decoration lives on the Ink below and Material
          // itself stays transparent.
          color: Colors.transparent,
          child: Ink(
            decoration: _decoration(enabled),
            child: InkWell(
              onTap: enabled ? onPressed : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                width: expand ? double.infinity : null,
                constraints: const BoxConstraints(minHeight: 54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
                alignment: Alignment.center,
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Decoration _decoration(bool enabled) {
    final radius = BorderRadius.circular(16);

    if (!enabled) {
      return BoxDecoration(
        color: AppColors.inputBorder,
        borderRadius: radius,
      );
    }

    return switch (kind) {
      RadiusButtonKind.primary => BoxDecoration(
          color: AppColors.primary,
          borderRadius: radius,
        ),
      RadiusButtonKind.ghost => BoxDecoration(
          color: AppColors.card,
          borderRadius: radius,
          border: Border.all(color: AppColors.inputBorder, width: 1.5),
        ),
      RadiusButtonKind.premium => BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.premium, AppColors.premiumDeep],
          ),
          borderRadius: radius,
        ),
    };
  }
}
