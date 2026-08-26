import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A selectable pill.
///
/// The one chip in the app. Onboarding, the filter sheet, the quick-filter row
/// and the profile view all use it — before this existed, three of those four
/// had grown their own near-identical copy.
///
/// ## Selection is never signalled by border alone
///
/// The palette is low-contrast warm neutrals, so a hairline border change is
/// not a reliable signal. Selecting a chip changes three things together:
/// fill, border, and label weight. That way the state survives a low-contrast
/// screen, greyscale, and colour-blindness.
class RadiusChip extends StatelessWidget {
  const RadiusChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Renders with a padlock and reads as unavailable. Still tappable — the tap
  /// should explain the gate rather than doing nothing.
  final bool locked;

  /// Optional leading icon, replaced by a padlock when [locked].
  final IconData? icon;

  /// Tighter padding for horizontal scroller rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final on = selected && !locked;

    final Color fill;
    final Color border;
    if (on) {
      fill = AppColors.primaryTint;
      border = AppColors.primary;
    } else {
      fill = AppColors.card;
      border = AppColors.inputBorder;
    }

    final textStyle = on
        ? AppTextStyles.chipSelected
        : AppTextStyles.chip.copyWith(
            color: locked ? AppColors.textGrey : AppColors.textDark,
          );

    final leading = locked ? Icons.lock_outline : icon;

    return Semantics(
      button: true,
      selected: on,
      enabled: !locked,
      label: locked ? '$label, locked' : label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          // Visible keyboard focus, which a bare GestureDetector never gave.
          focusColor: AppColors.primary.withValues(alpha: 0.12),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: dense ? 15 : 16,
              vertical: dense ? 9 : 10,
            ),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: border, width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  Icon(
                    leading,
                    size: 14,
                    color: locked
                        ? AppColors.textGrey
                        : (on ? AppColors.primaryInk : AppColors.textDark),
                  ),
                  const SizedBox(width: 6),
                ],
                Text(label, style: textStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays chips out in a wrapping grid with the standard gutters.
class RadiusChipWrap extends StatelessWidget {
  const RadiusChipWrap({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Wrap(spacing: 9, runSpacing: 9, children: children);
}
