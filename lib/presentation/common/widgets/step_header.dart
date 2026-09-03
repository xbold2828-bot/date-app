import 'package:dating_app/core/constants/app_constants.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/static_assets/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

/// The backend owns the canonical funnel length, so screens label themselves
/// with their real step number rather than a per-screen count that drifts as
/// screens are added.
const int kOnboardingStepCount = 10;

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
          staticImage(
            h:25.h,
            url: AppIcons.roundedLauncherIconNoBg,),
          spacerW(10),
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

/// Top chrome for every onboarding screen: back, wordmark, step counter and
/// progress track.
///
/// One widget so all ten steps read identically — and so the progress track
/// can never disagree with the step number.
class StepHeader extends StatelessWidget {
  const StepHeader({
    super.key,
    required this.step,
    required this.label,
    this.onBack,
    this.trailing,
  });

  /// 1-based position in the canonical funnel.
  final int step;

  /// The section name shown opposite the counter, e.g. "IDENTITY".
  final String label;

  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final canPop = onBack != null || Navigator.of(context).canPop();
    final progress = (step / kOnboardingStepCount).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 38,
                height: 38,
                child: canPop
                    ? _BackButton(onTap: onBack ?? () => Navigator.pop(context))
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(child: Wordmark(size: 17)),
              SizedBox(width: 38, child: trailing),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'STEP $step OF $kOnboardingStepCount',
                style: AppTextStyles.label.copyWith(color: AppColors.primary),
              ),
              Text(label.toUpperCase(), style: AppTextStyles.label),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Step $step of $kOnboardingStepCount',
            value: '${(progress * 100).round()} percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: AppColors.inputBorder,
                  valueColor: AlwaysStoppedAnimation(AppColors.primary),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The square back affordance used across onboarding and detail screens.
class _BackButton extends StatelessWidget {
  const _BackButton({required this.onTap});

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
            child: Icon(
              Icons.arrow_back,
              size: 19,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

/// A standalone back affordance for screens without a [StepHeader].
class RadiusBackButton extends StatelessWidget {
  const RadiusBackButton({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 38,
        height: 38,
        child: _BackButton(
          onTap: onTap ?? () => Navigator.pop(context),
        ),
      );
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
