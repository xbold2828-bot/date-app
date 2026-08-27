import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/utils/utils.dart';
import 'app_text.dart';

class CommonBagWidget extends StatelessWidget {
  final String text;
  final VoidCallback onClick;
  const CommonBagWidget({super.key, required this.text, required this.onClick});

  @override
  Widget build(BuildContext context) {
    final colorScheme=Theme.of(context).colorScheme;
    return InkWell(
      onTap: onClick,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w,vertical: 6.h),
        decoration: BoxDecoration(
          color: colorScheme.secondary,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppText(
              text: text,
              fontSize: 13,
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w600,
            ),
            spacerW(15),
            Icon(Icons.close,size: 15.r,
              color: colorScheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}
