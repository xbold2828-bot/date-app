import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../data/models/tag_model.dart';

/// Shared chrome for the onboarding funnel. The backend owns the canonical
/// 10-step order, so screens label themselves with their real step number
/// rather than a per-screen count that drifts as screens are added.
const int kOnboardingStepCount = 10;

/// Top bar (back + wordmark + optional trailing action) and the step progress
/// bar, so every funnel screen reads the same.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({
    super.key,
    required this.step,
    required this.label,
    this.onBack,
    this.trailing,
  });

  /// 1-based position in the canonical funnel.
  final int step;

  /// Section name shown opposite the step counter (e.g. "IDENTITY").
  final String label;

  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 24,
                child: canPop
                    ? GestureDetector(
                        onTap: onBack ?? () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back,
                            color: AppColors.textDark),
                      )
                    : null,
              ),
              const Expanded(
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.circle, size: 10, color: AppColors.primary),
                      SizedBox(width: 6),
                      Text(
                        'Radius',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 44, child: trailing),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP $step OF $kOnboardingStepCount',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 1.1,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textGrey,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: step / kOnboardingStepCount,
              minHeight: 3,
              backgroundColor: AppColors.inputBorder,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// The funnel's pill-shaped primary action.
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
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: active ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.textGrey.withOpacity(0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  color: AppColors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: enabled ? AppColors.white : AppColors.textGrey,
                ),
              ),
      ),
    );
  }
}

/// A selectable pill. Used for both free-standing options and catalogue tags.
class OnboardingChip extends StatelessWidget {
  const OnboardingChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shown with a padlock — selectable only once the user is verified.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withOpacity(0.1)
              : AppColors.white,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.inputBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (locked) ...[
              const Icon(Icons.lock_outline,
                  size: 13, color: AppColors.textGrey),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: locked
                    ? AppColors.textGrey
                    : (selected ? AppColors.primary : AppColors.textDark),
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final locked = tag.isSensitive && !viewerVerified;
        return OnboardingChip(
          label: tag.label,
          selected: selected.contains(tag.slug),
          locked: locked,
          onTap: locked ? (onLockedTap ?? () {}) : () => onToggle(tag.slug),
        );
      }).toList(),
    );
  }
}

/// Small uppercase section heading used between chip groups.
class OnboardingSectionLabel extends StatelessWidget {
  const OnboardingSectionLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.textGrey,
        letterSpacing: 1.2,
      ),
    );
  }
}
