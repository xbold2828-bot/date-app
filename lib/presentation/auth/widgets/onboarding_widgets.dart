import 'package:flutter/material.dart';

import '../../../data/models/tag_model.dart';
import '../../common/widgets/widgets.dart';

export '../../common/widgets/step_header.dart' show kOnboardingStepCount;

/// Onboarding's chrome, now drawn from the shared component library.
///
/// These names stay because twelve funnel screens call them, but the widgets
/// behind them are the same ones the rest of the app uses — so a change to a
/// chip lands in onboarding, the filter sheet and the profile view at once.
/// Before this, each of those had grown its own copy.
///
/// New screens should import `presentation/common/widgets/widgets.dart` and
/// use [RadiusChip] / [StepHeader] / [SectionLabel] directly.

/// The funnel's top chrome. See [StepHeader].
typedef OnboardingHeader = StepHeader;

/// A selectable pill. See [RadiusChip].
typedef OnboardingChip = RadiusChip;

/// Small uppercase heading between groups. See [SectionLabel].
typedef OnboardingSectionLabel = SectionLabel;

/// The funnel's primary action.
///
/// Kept as its own widget rather than a typedef because onboarding separates
/// "disabled because the form is incomplete" from "disabled because we are
/// mid-request" — [RadiusButton] takes a single nullable handler.
class OnboardingButton extends StatelessWidget {
  const OnboardingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;

  /// False greys the button out — the form is not ready yet.
  final bool enabled;

  @override
  Widget build(BuildContext context) => RadiusButton(
        label: label,
        isLoading: isLoading,
        onPressed: enabled ? onPressed : null,
      );
}

/// Multi-select chips backed by the curated tag catalogue.
///
/// Selection carries the tag *slug*, never the label — the API validates slugs
/// against the catalogue and rejects anything else.
class TagChipGroup extends StatelessWidget {
  const TagChipGroup({
    super.key,
    required this.tags,
    required this.selected,
    required this.onToggle,
    this.viewerVerified = true,
    this.onLockedTap,
  });

  final List<Tag> tags;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

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
          onTap: locked ? (onLockedTap ?? () {}) : () => onToggle(tag.slug),
        );
      }).toList(),
    );
  }
}
