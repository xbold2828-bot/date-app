import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../core/utils/utils.dart';
import 'app_text.dart';

class ResendLoader extends StatelessWidget {
  const ResendLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        spacerH(5),
        const AppText(
          text: "Resending OTP...",
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
        spacerH(5),
        ClipRRect(
          borderRadius: BorderRadius.circular(8.r),
          child: const LinearProgressIndicator(),
        ),
      ],
    );
  }
}