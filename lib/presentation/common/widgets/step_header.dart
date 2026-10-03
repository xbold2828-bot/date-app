import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/static_assets/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// The backend owns the canonical funnel length, so screens label themselves
/// with their real step number rather than a per-screen count that drifts as
/// screens are added.
const int kOnboardingStepCount = 8;

/// The cozune wordmark. The period is accent blue — the one flourish the brand
/// gets, and the reason the mark reads as a statement rather than a label.
class Wordmark extends StatelessWidget {
  const Wordmark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final style = AppTextStyles.title.copyWith(
      fontSize: size,
      color: color ?? AppColors.textDark,
    );
    return Semantics(
      header: true,
      label: AppConstants.appName,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          staticImage(h: 30.h, url: AppIcons.roundedLauncherIconNoBg),
          spacerW(5),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: AppConstants.appName, style: style),
                TextSpan(
                  text: '.',
                  style: style.copyWith(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Whether there is a page behind this one, asked of whichever navigator the
/// screen actually lives in.
///
/// The funnel runs under go_router, but one step (the live check) is pushed
/// imperatively and tests pump screens under a bare [MaterialApp]. Asking
/// `GoRouter.of` there throws; asking the nearest navigator never does.
bool routeCanPop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) return true;
  return Navigator.maybeOf(context)?.canPop() ?? false;
}

/// Pops through the same navigator [routeCanPop] consulted — the router when
/// there is one (exactly what `context.pop()` did before), the plain navigator
/// otherwise.
void routePop(BuildContext context) {
  final router = GoRouter.maybeOf(context);
  if (router != null && router.canPop()) {
    router.pop();
    return;
  }
  Navigator.maybeOf(context)?.maybePop();
}

/// Top chrome for every onboarding step: a row of story-style segments, one
/// per step, and under it the way back and where you are.
///
/// Segments rather than a percentage bar because eight short, separate pieces
/// say "eight quick questions" — the honest promise of this funnel — where one
/// long bar inching along says "form". The current step's segment fills as the
/// screen arrives, which is the only motion on it.
///
/// [label] names the section for screen readers only. On screen it was an
/// uppercase caption competing with the question for the first glance.
class StepHeader extends StatelessWidget {
  final bool isShowBackButton;
  const StepHeader({
    super.key,
    required this.step,
    required this.label,
    this.onBack,
    this.isShowBackButton = true,
    this.trailing,
  });

  /// 1-based position in the canonical funnel.
  final int step;

  /// The section name, e.g. "Identity". Announced, not drawn.
  final String label;

  /// Overrides the default pop.
  final VoidCallback? onBack;

  /// Sits at the right end of the row — "Skip", usually.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final showBack =
        isShowBackButton && (onBack != null || routeCanPop(context));

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: StepSegments(
              step: step,
              total: kOnboardingStepCount,
              section: label,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: showBack
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: BackChevron(
                            onTap: onBack ?? () => routePop(context),
                          ),
                        )
                      : null,
                ),
                Expanded(
                  child: ExcludeSemantics(
                    child: Text(
                      '$step of $kOnboardingStepCount',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 13,
                        color: AppColors.textGrey,
                        fontWeight: FontWeight.w600,
                        fontVariations: const [FontVariation('wght', 600)],
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: trailing == null
                      ? null
                      : Align(
                          alignment: Alignment.centerRight,
                          child: trailing,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// [total] thin segments; those before [step] full, the current one filling
/// in as it arrives, the rest waiting.
class StepSegments extends StatelessWidget {
  const StepSegments({
    super.key,
    required this.step,
    required this.total,
    this.section,
  });

  final int step;
  final int total;
  final String? section;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final current = step.clamp(1, total);

    return Semantics(
      label:
          'Step $current of $total'
          '${section == null || section!.isEmpty ? '' : ', ${_sentenceCase(section!)}'}',
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segment(
                fill: i < current - 1 ? 1 : (i == current - 1 ? null : 0),
                animate: !reduceMotion,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _sentenceCase(String s) {
    final lower = s.toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

class _Segment extends StatelessWidget {
  const _Segment({required this.fill, required this.animate});

  /// 0 or 1 for settled segments; null for the one filling in now.
  final double? fill;
  final bool animate;

  static const _easeOut = Cubic(0.23, 1, 0.32, 1);

  @override
  Widget build(BuildContext context) {
    Widget bar(double value) => ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3.5,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: AppColors.inputBorder),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value,
              child: ColoredBox(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );

    final settled = fill;
    if (settled != null) return bar(settled);
    if (!animate) return bar(1);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: _easeOut,
      builder: (context, value, _) => bar(value),
    );
  }
}

/// A plain back arrow with a full-size touch target — no box around it. The
/// boxed square it replaces was the loudest thing in the header.
class BackChevron extends StatelessWidget {
  const BackChevron({super.key, required this.onTap, this.color});

  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go back',
      excludeSemantics: true,
      child: SizedBox(
        width: 48,
        height: 48,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 24,
              color: color ?? AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// The square back affordance used across detail screens.
class BackButton extends StatelessWidget {
  const BackButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Go back',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.inputBorder),
            ),
            child: Icon(Icons.arrow_back, size: 19, color: AppColors.textDark),
          ),
        ),
      ),
    );
  }
}

/// A standalone back affordance for screens without a [StepHeader].
///
/// Renders nothing when there is no page to pop (and no custom [onTap]).
class RadiusBackButton extends StatelessWidget {
  const RadiusBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canPop = onTap != null || routeCanPop(context);
    if (!canPop) return const SizedBox.shrink();

    return SizedBox(
      width: 38,
      height: 38,
      child: BackButton(onTap: onTap ?? () => routePop(context)),
    );
  }
}

/// The sticky footer that holds a screen's primary action.
///
/// The gradient is doing real work: content scrolling underneath fades into
/// the ground instead of colliding with the button.
class StickyFooter extends StatelessWidget {
  const StickyFooter({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        22,
        18,
        22,
        20 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // The transparent stop has to be the ground colour at zero alpha,
          // not Colors.transparent: a fade to transparent black greys the
          // middle of the ramp on a light ground.
          colors: [
            AppColors.background.withValues(alpha: 0),
            AppColors.background,
          ],
          stops: const [0, 0.4],
        ),
      ),
      child: child,
    );
  }
}
