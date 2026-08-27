import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/padding_extension.dart';
import '../../../../core/utils/utils.dart';
import '../../app_text.dart';
import '../../buttons/common_button.dart';
import '../../buttons/common_outlined_button.dart';

class CommonDialog extends StatelessWidget {
  final String headingText;
  final bool isShowTwoButtons;
  final String descriptionText;
  final String buttonText;
  final VoidCallback onTap;
  final IconData? iconData;
  final String? vectorLogo;
  final String? imageLogo;

  const CommonDialog({
    super.key,
    required this.isShowTwoButtons,
    required this.headingText,
    required this.descriptionText,
    required this.buttonText,
    required this.onTap,
    this.iconData,
    this.vectorLogo,
    this.imageLogo,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 20.w),
      backgroundColor: colorScheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spacerH(15),

          if (vectorLogo != null) ...[
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 40.r,
              child: Center(child: SvgPicture.asset(vectorLogo!)),
            ),
          ],

          if (iconData != null) ...[
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 40.r,
              child: Center(child: Icon(iconData)),
            ),
          ],

          if (imageLogo != null) ...[
            CircleAvatar(
              backgroundColor: colorScheme.primary,
              radius: 40.r,
              child: Center(child: SvgPicture.asset(imageLogo!)),
            ),
          ],

          spacerH(20),

          AppText(
            text: headingText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            textAlign: TextAlign.center,
            height: 1.25, // line height = 25
          ).paddingSymmetric(horizontal: 10.w),
          spacerH(5),

          AppText(
            text: descriptionText,
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: colorScheme.onSurface.withValues(alpha: 0.6),
            textAlign: TextAlign.center,
          ),
          spacerH(20),

          Row(
            children: [
              if (isShowTwoButtons)
                Expanded(
                  child: CommonOutlinedButton(
                    height: 44,
                    text: "Cancel",
                    onClick: () {
                      context.pop();
                    },
                  ),
                ),

              if (isShowTwoButtons) spacerW(10),

              Expanded(
                child: CommonButton(
                  height: 44,
                  bgColor: colorScheme.primary,
                  text: buttonText,
                  onClick: () {
                    context.pop(true);
                    onTap();
                  },
                ),
              ),
            ],
          ).paddingSymmetric(horizontal: 10.w),
          spacerH(10),
        ],
      ).paddingAll(20.r),
    );
  }
}
