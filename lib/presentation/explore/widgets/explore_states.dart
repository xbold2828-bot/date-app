import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
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

/// A floating card with a mark, a headline, a line of explanation and — always
/// — a way forward. Backs the empty, error and permission states, so all three
/// read as the same object rather than three improvised layouts.
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

    return Semantics(
      container: true,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: GlassSurface(
          radius: 24,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.12),
                ),
                child: Icon(icon, size: 26, color: accent),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.title.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
              if (primaryLabel != null && onPrimary != null) ...[
                const SizedBox(height: 16),
                RadiusButton(label: primaryLabel!, onPressed: onPrimary),
              ],
              if (secondaryLabel != null && onSecondary != null) ...[
                const SizedBox(height: 8),
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

enum ExploreNoticeTone { neutral, warning }
