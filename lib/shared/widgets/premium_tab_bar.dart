import 'package:dating_app/core/constants/app_text_styles.dart';
import 'package:dating_app/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// One tab in a [PremiumTabBar].
class PremiumTabItem {
  const PremiumTabItem({
    required this.label,
    this.icon,
    this.count,
    this.semanticLabel,
  });

  final String label;
  final IconData? icon;

  /// Shows a badge when > 0. Leave null to hide it.
  final int? count;

  /// Overrides the screen-reader label (defaults to "label, count").
  final String? semanticLabel;
}


class PremiumTabBar extends StatelessWidget {
  const PremiumTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
    this.maxWidth = 520,
  });

  final TabController controller;
  final List<PremiumTabItem> tabs;
  final EdgeInsetsGeometry margin;

  /// Widest the bar is allowed to get (keeps it tidy on tablets).
  final double maxWidth;

  static const double _height = 44;
  static const double _trackPadding = 4;

  /// Below this per-tab width the icon is hidden to save room.
  static const double _minWidthForIcon = 120;

  @override
  Widget build(BuildContext context) {
    assert(
    tabs.length == controller.length,
    'PremiumTabBar: tabs.length must match TabController.length',
    );

    final isDark = AppColors.isDark;
    final media = MediaQuery.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: MediaQuery(
          // Cap accessibility font scaling so the bar never outgrows its track.
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 1.15),
          ),
          child: Container(
            margin: margin,
            padding: const EdgeInsets.all(_trackPadding),
            decoration: BoxDecoration(
              color: isDark ? AppColors.background : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.22),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final count = tabs.length;
                final tabWidth = constraints.maxWidth / count;
                final showIcon = tabWidth >= _minWidthForIcon;

                return SizedBox(
                  height: _height,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Sliding blue pill – follows taps AND swipes.
                      _SlidingPill(controller: controller, count: count),

                      // Equal-width tabs on top of the pill.
                      Row(
                        children: [
                          for (var i = 0; i < count; i++)
                            Expanded(
                              child: _PremiumTab(
                                item: tabs[i],
                                index: i,
                                controller: controller,
                                showIcon: showIcon,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// The blue indicator. Slides smoothly between tabs using the controller's
/// animation value, so it also tracks a finger swipe in real time.
class _SlidingPill extends StatelessWidget {
  const _SlidingPill({required this.controller, required this.count});

  final TabController controller;
  final int count;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        final pos = controller.animation?.value ?? controller.index.toDouble();
        // Alignment.x: -1 = far left, 1 = far right.
        final x = count <= 1 ? 0.0 : -1 + 2 * (pos / (count - 1));

        return Align(
          alignment: Alignment(x.clamp(-1.0, 1.0), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / count,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AppColors.primary,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PremiumTab extends StatelessWidget {
  const _PremiumTab({
    required this.item,
    required this.index,
    required this.controller,
    required this.showIcon,
  });

  final PremiumTabItem item;
  final int index;
  final TabController controller;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final count = item.count;
    final hasCount = count != null && count > 0;

    return AnimatedBuilder(
      animation: controller.animation ?? controller,
      builder: (context, _) {
        // 1.0 = this tab fully selected, 0.0 = idle (follows swipes).
        final pos = controller.animation?.value ?? controller.index.toDouble();
        final t = (1 - (pos - index).abs()).clamp(0.0, 1.0);
        final color = Color.lerp(AppColors.textGrey, onPrimary, t)!;

        return Semantics(
          button: true,
          selected: controller.index == index,
          label: item.semanticLabel ??
              (hasCount ? '${item.label}, $count' : item.label),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => controller.animateTo(index),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (item.icon != null && showIcon) ...[
                        Icon(item.icon, size: 16, color: color),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        item.label,
                        maxLines: 1,
                        softWrap: false,
                        style: AppTextStyles.bodyStrong.copyWith(
                          fontSize: 14,
                          letterSpacing: 0.2,
                          color: color,
                          fontWeight:
                          t > 0.5 ? FontWeight.w700 : FontWeight.w600,
                          fontVariations: [
                            FontVariation('wght', t > 0.5 ? 700 : 600),
                          ],
                        ),
                      ),
                      if (hasCount) ...[
                        const SizedBox(width: 8),
                        _CountBadge(count: count, selectedAmount: t),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.selectedAmount});

  final int count;

  final double selectedAmount;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // Selected tab: frosted chip on top of the blue pill.
    final frosted = onPrimary.withValues(alpha: 0.26);
    final fill = Color.lerp(AppColors.primary, frosted, selectedAmount)!;

    return Container(
      height: 20,
      constraints: const BoxConstraints(minWidth: 20),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: onPrimary.withValues(alpha: 0.30 * selectedAmount),
          width: 0.8,
        ),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          count > 99 ? '99+' : '$count',
          textHeightBehavior: const TextHeightBehavior(
            applyHeightToFirstAscent: false,
            applyHeightToLastDescent: false,
          ),
          style: AppTextStyles.caption.copyWith(
            fontSize: 11.5,
            height: 1.0,
            color: onPrimary,
            fontWeight: FontWeight.w700,
            fontVariations: const [FontVariation('wght', 700)],
          ),
        ),
      ),
    );
  }
}