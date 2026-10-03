import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// A card on the page ground. The default container for grouped
/// content.
class RadiusCard extends StatelessWidget {
  const RadiusCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
    this.tinted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Fills with the accent tint, for cards that are themselves a selection.
  final bool tinted;

  @override
  Widget build(BuildContext context) {
    final decorated = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tinted ? AppColors.primaryTint : AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: tinted ? AppColors.primarySoft : AppColors.inputBorder,
          width: 1.5,
        ),
      ),
      child: child,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: decorated,
      ),
    );
  }
}

/// The thing someone needs to know before they act — a privacy note, a store
/// rule, a consequence — set as a quiet footnote with a mark beside it.
///
/// It used to be an outlined box, and a box reads as a warning whatever it
/// says. These explain; they do not warn.
class NoticeBox extends StatelessWidget {
  const NoticeBox({super.key, required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 17, color: AppColors.iconMuted),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            text,
            style: AppTextStyles.caption.copyWith(fontSize: 13, height: 1.5),
          ),
        ),
      ],
    );
  }
}

/// A read-only pill stating a fact about someone — an intent, a vibe, a
/// verification. Not tappable; for a control, use [RadiusChip].
class TagPill extends StatelessWidget {
  const TagPill({
    super.key,
    required this.label,
    this.icon,
    this.tone = TagTone.accent,
  });

  final String label;
  final IconData? icon;
  final TagTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, ink) = switch (tone) {
      TagTone.accent => (AppColors.primaryTint, AppColors.primaryInk),
      TagTone.premium => (AppColors.premiumTint, AppColors.premiumInk),
      TagTone.neutral => (AppColors.card, AppColors.textGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: tone == TagTone.neutral
            ? Border.all(color: AppColors.inputBorder)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: ink),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ],
      ),
    );
  }
}

enum TagTone { accent, premium, neutral }

/// The heading that opens a group within a screen, in sentence case — the
/// way the label is written is the way it is shown.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key, this.topSpacing = 26});

  final String label;

  /// Space above. The default is the standard gap between groups; pass 0 when
  /// the label opens a screen.
  final double topSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: 12),
      child: Semantics(
        header: true,
        child: Text(label, style: AppTextStyles.label),
      ),
    );
  }
}

/// A row of the vibe agreement, safety tips, and premium benefits — a tick
/// and a line of prose.
class TickRow extends StatelessWidget {
  const TickRow({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.check, size: 17, color: AppColors.ok),
          ),
          const SizedBox(width: 10),
          Expanded(child: child),
        ],
      ),
    );
  }
}
