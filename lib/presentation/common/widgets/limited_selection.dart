import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../data/models/tag_model.dart';
import 'radius_chip.dart';

/// Selection with a ceiling, and one rule for what happens at it.
///
/// The funnel and the "Me" editor ask the same four questions, so the arithmetic
/// lives here rather than being written twice with two different ideas of what
/// a full list does.
///
/// ## What "full" means depends on the question
///
/// A one-of question ("here for", "my situation") is a radio group: picking a
/// second answer *replaces* the first, because refusing the tap would leave the
/// person hunting for the deselect. A three-of question is a budget: the fourth
/// tap is refused and says so, because silently dropping the oldest choice
/// would change an answer the person did not touch.
Set<String>? applySelectionLimit(
  Set<String> current,
  String value,
  int? max,
) {
  if (current.contains(value)) return {...current}..remove(value);
  if (max == null || current.length < max) return {...current, value};
  // One-of: swap. Many-of: refuse, and let the caller explain.
  if (max == 1) return {value};
  return null;
}

/// "2 / 3" — how much of the budget is spent.
///
/// Turns accent blue on the last slot so the cap is visible *before* it is hit,
/// which is the difference between a limit and a rejection.
class SelectionCounter extends StatelessWidget {
  const SelectionCounter({super.key, required this.count, required this.max});

  final int count;
  final int max;

  @override
  Widget build(BuildContext context) {
    final full = count >= max;
    return Semantics(
      label: '$count of $max selected',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: full ? AppColors.primaryTint : AppColors.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: full ? AppColors.primary : AppColors.inputBorder,
          ),
        ),
        child: Text(
          '$count/$max',
          style: AppTextStyles.caption.copyWith(
            fontSize: 11,
            color: full ? AppColors.primaryInk : AppColors.textGrey,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    );
  }
}

/// Curated tag chips that stop at [max].
///
/// Selection carries the tag *slug*, never the label — the API validates slugs
/// against the catalogue and rejects anything else.
///
/// Chips beyond the cap are not disabled. A greyed-out chip cannot explain
/// itself, and the tap that lands on it is exactly the moment the person wants
/// to know why — so they stay live and answer with [onLimitReached].
class LimitedTagChipGroup extends StatelessWidget {
  const LimitedTagChipGroup({
    super.key,
    required this.tags,
    required this.selected,
    required this.onChanged,
    required this.onLimitReached,
    this.max,
    this.viewerVerified = true,
    this.onLockedTap,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  /// Called when a tap is refused because the list is already full.
  final VoidCallback onLimitReached;

  /// Null means unlimited — hard no's, which are boundaries rather than
  /// preferences and are never capped.
  final int? max;

  /// Sensitive tags are verified-members-only; they render locked otherwise.
  final bool viewerVerified;
  final VoidCallback? onLockedTap;

  @override
  Widget build(BuildContext context) {
    return RadiusChipWrap(
      children: tags.map((tag) {
        final locked = tag.isSensitive && !viewerVerified;
        return RadiusChip(
          label: tag.label,
          selected: selected.contains(tag.slug),
          locked: locked,
          onTap: locked
              ? (onLockedTap ?? () {})
              : () {
                  final next = applySelectionLimit(selected, tag.slug, max);
                  next == null ? onLimitReached() : onChanged(next);
                },
        );
      }).toList(),
    );
  }
}

/// Plain-label chips that stop at [max] — the same rules as
/// [LimitedTagChipGroup], for the questions answered with enum values rather
/// than catalogue tags ("here for", "my situation").
class LimitedLabelChipGroup extends StatelessWidget {
  const LimitedLabelChipGroup({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    required this.onLimitReached,
    this.max,
  });

  /// Value → label. Selection carries the value.
  final List<MapEntry<String, String>> options;

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;
  final VoidCallback onLimitReached;
  final int? max;

  @override
  Widget build(BuildContext context) {
    return RadiusChipWrap(
      children: options
          .map(
            (option) => RadiusChip(
              label: option.value,
              selected: selected.contains(option.key),
              onTap: () {
                final next = applySelectionLimit(selected, option.key, max);
                next == null ? onLimitReached() : onChanged(next);
              },
            ),
          )
          .toList(),
    );
  }
}
