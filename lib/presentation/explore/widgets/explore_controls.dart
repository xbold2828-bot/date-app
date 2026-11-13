import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../../core/constants/app_string.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../providers/explore_provider.dart';

/// Floating bar decoration that matches the bottom navigation bar.
BoxDecoration floatingBarDecoration({double radius = 28}) {
  return BoxDecoration(
    color: AppColors.isDark
        ? AppColors.greyColor.withValues(alpha: 0.5)
        : AppColors.whiteColor,
    borderRadius: BorderRadius.circular(radius),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.12),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}

/// Blurred, translucent surface used by the pills and toggles over the map.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 18,
    this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    this.onTap,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    return ClipRRect(
      borderRadius: shape,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.panel.withValues(alpha: 0.82),
            borderRadius: shape,
            border: Border.all(
              color: AppColors.inputBorder.withValues(alpha: 0.75),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.textDark.withValues(alpha: 0.12),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: Padding(padding: padding, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// "5 people vibing" pill. "Vibing" is the app's word for a conversation both
/// people are in, which is exactly who appears on this map.
class ExploreCountPill extends StatelessWidget {
  const ExploreCountPill({
    super.key,
    required this.count,
    required this.isLoading,
  });

  final int count;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? AppString.exploreCountLoading
        : AppString.exploreCount(count);

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.people_alt_outlined,
              size: 16,
              color: AppColors.blue,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 12,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ExploreViewToggle extends StatelessWidget {
  const ExploreViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ExploreViewMode mode;
  final ValueChanged<ExploreViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 999,
      padding: const EdgeInsets.all(4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _segment(ExploreViewMode.flat, '2D'),
          _segment(ExploreViewMode.tilted, '3D'),
        ],
      ),
    );
  }

  Widget _segment(ExploreViewMode value, String label) {
    final selected = mode == value;
    return Semantics(
      button: true,
      selected: selected,
      label: value == ExploreViewMode.flat
          ? 'Flat map view'
          : 'Tilted 3D map view',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: selected ? null : () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            color: selected ? AppColors.blue : null,
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12.5,
              color: selected ? AppColors.onAccent : AppColors.textDark,
              fontWeight: FontWeight.w700,
              fontVariations: const [FontVariation('wght', 700)],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the map is focused on one person. Tap to show everyone again.
class ExploreFocusPill extends StatelessWidget {
  const ExploreFocusPill({
    super.key,
    required this.name,
    required this.onShowEveryone,
    this.distance,
  });

  final String name;

  /// Real distance such as "450 m away". Null when it is unknown.
  final String? distance;

  final VoidCallback onShowEveryone;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: distance == null
          ? 'Showing $name only. Tap to show everyone again.'
          : 'Showing $name only, $distance. Tap to show everyone again.',
      excludeSemantics: true,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
        onTap: onShowEveryone,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_pin_circle_outlined,
              size: 16,
              color: AppColors.blue,
            ),
            const SizedBox(width: 7),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Showing $name',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12.5,
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w700,
                      fontVariations: const [FontVariation('wght', 700)],
                    ),
                  ),
                  if (distance != null)
                    Text(
                      distance!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(fontSize: 11),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primaryTint,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Show all',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11.5,
                  color: AppColors.primaryInk,
                  fontWeight: FontWeight.w700,
                  fontVariations: const [FontVariation('wght', 700)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}