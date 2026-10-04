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

/// Pill / segmented tab bar that matches the app's [CommonButton] colours.
class PremiumTabBar extends StatelessWidget {
  const PremiumTabBar({
    super.key,
    required this.controller,
    required this.tabs,
    this.margin = const EdgeInsets.symmetric(horizontal: 20),
  });

  final TabController controller;
  final List<PremiumTabItem> tabs;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    assert(
    tabs.length == controller.length,
    'PremiumTabBar: tabs.length must match TabController.length',
    );

    final isDark = AppColors.isDark;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Container(
      margin: margin,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.background : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: isDark ? 0.28 : 0.22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TabBar(
        controller: controller,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        labelPadding: EdgeInsets.zero,
        indicatorPadding: EdgeInsets.zero,
        labelColor: onPrimary,
        unselectedLabelColor: AppColors.textGrey,
        labelStyle: AppTextStyles.bodyStrong.copyWith(
          fontSize: 14,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wght', 700)],
        ),
        unselectedLabelStyle: AppTextStyles.bodyStrong.copyWith(
          fontSize: 14,
          letterSpacing: 0.2,
          fontWeight: FontWeight.w600,
          fontVariations: const [FontVariation('wght', 600)],
        ),
        // Flat blue pill, no shadow.
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AppColors.primary,
        ),
        tabs: [
          for (var i = 0; i < tabs.length; i++)
            _PremiumTab(item: tabs[i], index: i, controller: controller),
        ],
      ),
    );
  }
}

class _PremiumTab extends StatelessWidget {
  const _PremiumTab({
    required this.item,
    required this.index,
    required this.controller,
  });

  final PremiumTabItem item;
  final int index;
  final TabController controller;

  @override
  Widget build(BuildContext context) {
    final count = item.count;
    final hasCount = count != null && count > 0;

    return Tab(
      height: 44,
      child: Semantics(
        label: item.semanticLabel ??
            (hasCount ? '${item.label}, $count' : item.label),
        excludeSemantics: true,
        child: AnimatedBuilder(
          animation: controller.animation ?? controller,
          builder: (context, _) {
            // 1.0 = this tab fully selected, 0.0 = idle (follows swipes).
            final pos =
                controller.animation?.value ?? controller.index.toDouble();
            final t = (1 - (pos - index).abs()).clamp(0.0, 1.0);

            return Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 16),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasCount) ...[
                  const SizedBox(width: 8),
                  _CountBadge(count: count, selectedAmount: t),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count, required this.selectedAmount});

  final int count;

  /// 0 → tab idle, 1 → tab selected. Drives a smooth colour cross-fade.
  final double selectedAmount;

  @override
  Widget build(BuildContext context) {
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    // Idle tab:     solid blue chip.
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