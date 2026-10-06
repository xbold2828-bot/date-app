import 'package:dating_app/shared/widgets/buttons/common_outlined_button.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import 'explore_controls.dart';

enum ExploreNoticeTone { neutral, warning }

/// Small pill shown while people load. The map stays usable underneath.
class ExploreLoadingPill extends StatelessWidget {
  const ExploreLoadingPill({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final text = message ?? 'Finding people around you…';

    return Semantics(
      liveRegion: true,
      label: text,
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(text, style: AppTextStyles.caption.copyWith(fontSize: 12.5)),
          ],
        ),
      ),
    );
  }
}

class ExploreNoticeCard extends StatelessWidget {
  const ExploreNoticeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.tone = ExploreNoticeTone.neutral,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final ExploreNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final accent = tone == ExploreNoticeTone.warning
        ? AppColors.warning
        : AppColors.primary;

    final hasPrimary = primaryLabel != null && onPrimary != null;
    final hasSecondary = secondaryLabel != null && onSecondary != null;

    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.inputBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppColors.isDark ? 0.35 : 0.08,
                ),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 25, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 13,
                  height: 1.4,
                ),
              ),

              if (hasPrimary) ...[
                const SizedBox(height: 16),
                CommonOutlinedButton(
                  height: 40,
                  text: primaryLabel!, onClick: onPrimary!,
                ),
              ],
              if (hasSecondary) ...[
                const SizedBox(height: 4),
                RadiusButton(
                  label: secondaryLabel!,
                  kind: RadiusButtonKind.ghost,
                  onPressed: onSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
