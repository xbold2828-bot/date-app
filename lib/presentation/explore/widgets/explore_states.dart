import 'package:dating_app/shared/widgets/buttons/common_button.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../common/widgets/widgets.dart';
import 'explore_controls.dart';

/// The cards Explore floats over the map when it has something to say.
///
/// All of them are *over* the map, never instead of it. A blank screen while
/// people load, or a full-bleed error page when one request failed, throws away
/// a city the user was already looking at — and on a map, "nothing here" and
/// "nothing loaded" look identical unless the map is still there to tell them
/// apart.

/// The quiet indicator during a fetch.
///
/// Shown as a pill rather than a spinner over a scrim: the map underneath stays
/// usable, and a first load has the marker layer arriving progressively behind
/// this anyway.
class ExploreLoadingPill extends StatelessWidget {
  const ExploreLoadingPill({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: message ?? 'Finding people around you',
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Text(
              message ?? 'Finding people around you…',
              style: AppTextStyles.caption.copyWith(fontSize: 12.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// A floating notice card with a layered icon mark, a headline, a line of
/// explanation and — always — a way forward. Backs the empty, error and
/// permission states, so all three read as the same object.
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
    final accent = switch (tone) {
      ExploreNoticeTone.neutral => AppColors.primary,
      ExploreNoticeTone.warning => AppColors.warning,
    };
    final isDark = AppColors.isDark;

    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: isDark ? AppColors.background : Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? 0.28 : 0.16),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? 0.20 : 0.14),
                blurRadius: 40,
                spreadRadius: -6,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(26, 32, 26, 22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _IconMark(icon: icon, accent: accent),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.title.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.caption.copyWith(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                if (primaryLabel != null && onPrimary != null) ...[
                  const SizedBox(height: 26),
                  CommonButton(text: primaryLabel!, onClick: onPrimary),
                ],
                if (secondaryLabel != null && onSecondary != null) ...[
                  const SizedBox(height: 6),
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
      ),
    );
  }
}

/// Three concentric rings around a solid core, so the icon feels anchored
/// instead of sitting in a flat circle.
class _IconMark extends StatelessWidget {
  const _IconMark({required this.icon, required this.accent});

  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 108,
      height: 108,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.06),
            ),
          ),
          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent,
            ),
            child: Icon(
              icon,
              size: 28,
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

enum ExploreNoticeTone { neutral, warning }
