import 'package:dating_app/core/constants/static_assets/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/padding_extension.dart';
import '../../../../core/utils/utils.dart';
import '../../app_text.dart';
import '../../buttons/common_button.dart';
import '../../buttons/common_outlined_button.dart';

/// A premium-styled dialog for the "buy premium OR watch an ad" paywall
/// moment (e.g. thrown as [EntitlementRequiredException] from the API).
///
/// Everything is dynamic — heading, description, both button labels/actions,
/// and the badge icon — so it can be reused anywhere the app needs to offer
/// that choice, not just for one specific gate.
class PremiumOrAdDialog extends StatelessWidget {
  /// Dialog heading, e.g. "Out of Likes".
  final String headingText;

  /// Supporting copy, e.g. "Upgrade to Premium or watch a short ad to keep
  /// swiping.".
  final String descriptionText;

  /// Label for the primary (premium) button. Defaults to "Buy Premium".
  final String buyButtonText;

  /// Label for the secondary (ad) button. Defaults to "Watch Ad".
  final String watchAdButtonText;

  /// Called when the primary button is tapped. The dialog closes first.
  final VoidCallback onBuyPremium;

  /// Called when the secondary button is tapped. The dialog closes first.
  final VoidCallback onWatchAd;

  /// Optional badge icon (drawn from Material icons). Ignored if
  /// [vectorAsset] is provided.
  final IconData? iconData;

  /// Optional badge icon from an SVG asset (e.g. a crown icon). Takes
  /// priority over [iconData] when both are supplied.
  final String? vectorAsset;

  /// Whether tapping the scrim dismisses the dialog. Defaults to false so
  /// the user makes an explicit choice — the cross icon is always there for
  /// an intentional close.
  final bool dismissible;

  const PremiumOrAdDialog({
    super.key,
    required this.headingText,
    required this.descriptionText,
    required this.onBuyPremium,
    required this.onWatchAd,
    this.buyButtonText = 'Buy Premium',
    this.watchAdButtonText = 'Watch Ad',
    this.iconData,
    this.vectorAsset,
    this.dismissible = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient header carrying the badge — this is what makes it
              // read as "premium" rather than a generic alert dialog.
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 28.h, bottom: 36.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withValues(alpha: 0.7),
                    ],
                  ),
                ),
                child: Center(
                  child: vectorAsset==null?
                  ClipOval(
                    child: staticImage(
                      w:80.w,
                      h: 80.h,
                      url: AppIcons.appLogo,
                    ),
                  ):
                  Container(
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colorScheme.onPrimary,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 12.r,
                          offset: Offset(0, 4.h),
                        ),
                      ],
                    ),
                    child: SvgPicture.asset(
                      vectorAsset!,
                      width: 32.w,
                      height: 32.w,
                      colorFilter: ColorFilter.mode(
                        colorScheme.primary,
                        BlendMode.srcIn,
                      ),
                    )
                  ),
                ),
              ),

              spacerH(20),

              AppText(
                text: headingText,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                textAlign: TextAlign.center,
                height: 1.25,
              ).paddingSymmetric(horizontal: 20.w),
              spacerH(6),

              AppText(
                text: descriptionText,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: colorScheme.onSurface.withValues(alpha: 0.6),
                textAlign: TextAlign.center,
              ).paddingSymmetric(horizontal: 20.w),

              spacerH(24),

              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: CommonButton(
                      height: 46,
                      bgColor: colorScheme.primary,
                      text: buyButtonText,
                      onClick: () {
                        context.pop();
                        onBuyPremium();
                      },
                    ),
                  ),
                  spacerH(10),
                  SizedBox(
                    width: double.infinity,
                    child: CommonOutlinedButton(
                      height: 46,
                      text: watchAdButtonText,
                      onClick: () {
                        context.pop(true);
                        onWatchAd();
                      },
                    ),
                  ),
                ],
              ).paddingSymmetric(horizontal: 20.w),

              spacerH(20),
            ],
          ),

          // Cross icon — always available regardless of `dismissible`, so
          // there's an obvious explicit way out even when tapping the
          // scrim is disabled.
          Positioned(
            top: 12.h,
            right: 12.w,
            child: GestureDetector(
              onTap: () => context.pop(),
              child: Container(
                padding: EdgeInsets.all(6.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.onPrimary.withValues(alpha: 0.9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 6.r,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}