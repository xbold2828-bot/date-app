import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A single-choice row: title, supporting line, and a radio mark.
///
/// Used wherever the answer is one-of-several — relationship status, search
/// radius, subscription plan. For yes/no or many-of-several, use a chip.
///
/// Selection changes the border's colour and weight and fills the mark — never
/// the hairline alone. The card itself stays the page colour: a tinted fill on
/// top of a coloured border on top of a filled mark was three ways of saying
/// one thing.
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
    this.accent,
    this.inGroup = false,
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

  /// The selection colour. Accent blue unless the choice costs money, when
  /// it is premium purple.
  final Color? accent;

  /// Drawn as one row of a [RadiusOptionGroup] — no card of its own; the
  /// group's outline and hairlines hold the rows together.
  final bool inGroup;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.primary;

    return Semantics(
      button: true,
      selected: showRadio ? selected : null,
      label: subtitle == null ? title : '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: inGroup ? null : BorderRadius.circular(18),
          child: inGroup
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: _content(color),
                )
              : Container(
                  // A Container adds its border's width to the padding, so
                  // the thicker selected border gives back the extra half
                  // pixel here and the content stays put when chosen.
                  padding: selected
                      ? const EdgeInsets.symmetric(
                          horizontal: 17.5,
                          vertical: 15.5,
                        )
                      : const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: selected ? color : AppColors.inputBorder,
                      width: selected ? 2 : 1.5,
                    ),
                  ),
                  child: _content(color),
                ),
        ),
      ),
    );
  }

  Widget _content(Color color) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 14),
        ] else if (showRadio) ...[
          _RadioMark(selected: selected, color: color),
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
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontVariations: [FontVariation('wght', selected ? 700 : 500)],
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTextStyles.caption),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 12), trailing!],
      ],
    );
  }
}

/// Several [RadiusOptionTile]s — built with `inGroup: true` — as one list:
/// a single outline, hairlines between the rows. For settings, where the
/// options are one question and four separate cards made them look like four.
class RadiusOptionGroup extends StatelessWidget {
  const RadiusOptionGroup({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: AppColors.inputBorder,
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _RadioMark extends StatelessWidget {
  const _RadioMark({required this.selected, required this.color});

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color: selected ? color : AppColors.inputBorder,
          width: 2,
        ),
      ),
      child: selected
          ? Icon(Icons.check, size: 13, color: AppColors.onAccent)
          : null,
    );
  }
}
