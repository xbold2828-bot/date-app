import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A single-choice row: title, supporting line, and a radio mark.
///
/// Used wherever the answer is one-of-several — relationship status, search
/// radius, subscription plan. For yes/no or many-of-several, use a chip.
///
/// Like [RadiusChip], selection changes fill, border and mark together rather
/// than relying on the hairline alone.
class RadiusOptionTile extends StatelessWidget {
  const RadiusOptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.leading,
    this.trailing,
    this.showRadio = true,
  });

  final String title;

  /// The line under the title. Say what choosing this actually means.
  final String? subtitle;

  final bool selected;
  final VoidCallback onTap;

  /// An emoji or icon standing in for the radio mark, for tiles that navigate
  /// rather than choose.
  final Widget? leading;

  final Widget? trailing;

  /// False for tiles that act as navigation rather than a choice.
  final bool showRadio;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: showRadio ? selected : null,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: selected ? AppColors.primaryTint : AppColors.card,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? AppColors.primary : AppColors.inputBorder,
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 14),
                ] else if (showRadio) ...[
                  _RadioMark(selected: selected),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 15.5,
                          color: selected
                              ? AppColors.primaryInk
                              : AppColors.textDark,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(subtitle!, style: AppTextStyles.caption),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? AppColors.primary : Colors.transparent,
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.inputBorder,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 13, color: AppColors.onAccent)
          : null,
    );
  }
}
