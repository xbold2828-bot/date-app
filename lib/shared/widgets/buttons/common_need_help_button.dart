import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/constants/static_assets/app_vectors.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';

class CommonNeedHelpButton extends StatelessWidget {
  final VoidCallback? onClick;
  final bool isCenter;

  const CommonNeedHelpButton({super.key, this.onClick, this.isCenter = false});

  @override
  Widget build(BuildContext context) {
    // We remove the Align and Padding logic entirely
    // because the Scaffold will handle positioning.
    return InkWell(
      onTap:
          onClick ??
          () async {
            const String phoneNumber = "+917121212121";
            const String message =
                "Hello Dating App Team!\nI'm facing an issue. Please help me.";
            final number = phoneNumber.replaceAll('+', '').replaceAll(' ', '');
            final encodedMessage = Uri.encodeComponent(message);
            final uri = Uri.parse("https://wa.me/$number?text=$encodedMessage");
            await openUrl(isExternal: true, newUri: uri);
          },
      child: Container(
        height: 50.h,
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        alignment: isCenter ? Alignment.center : null,
        decoration: BoxDecoration(
          color: AppColors.lightGreen,
          borderRadius: BorderRadius.circular(30.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(AppVectors.whatsapp, width: 24.w, height: 24.h),
            SizedBox(width: 5.w),
            const Flexible(
              child: AppText(
                text: "Need Help?",
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
