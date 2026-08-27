import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../app_text.dart';

class CommonSmallButton extends StatelessWidget {
  final String text;
  final Color? bgColor;
  final VoidCallback onTap;
  final double? width;
  final double? height;
  final double? fontSize;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? buttonTextPadding;

  const CommonSmallButton({
    super.key,
    required this.text,
    required this.onTap,
    this.width,
    this.height,
    this.bgColor,
    this.borderRadius,
    this.fontSize,
    this.buttonTextPadding,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius ?? BorderRadius.circular(8.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius ?? BorderRadius.circular(8.r),
        // splashColor: Colors.transparent,
        // highlightColor: Colors.transparent,
        child: IntrinsicWidth(
          child: Container(
            width: width,
            height: height ?? 40.h,
            alignment: Alignment.center,
            padding:
                buttonTextPadding ??
                EdgeInsets.symmetric(vertical: 5.h, horizontal: 10.w),
            decoration: BoxDecoration(
              borderRadius: borderRadius ?? BorderRadius.circular(8.r),
              border: Border.all(
                color: bgColor ?? colorScheme.onSurface.withValues(alpha: 0.15),
              ),
            ),
            child: AppText(
              text: text,
              color: bgColor ?? colorScheme.onSurface.withValues(alpha: 0.6),
              fontSize: fontSize ?? 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
