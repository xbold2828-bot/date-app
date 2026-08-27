import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../app_text.dart';

AppBar titleAppBar({
  required BuildContext context,
  required String title,
  double? height,
  IconData? actionIcon,
  VoidCallback? onPressedAction,
}) {

  final canPop = context.canPop(); // GoRouter

  return AppBar(
    toolbarHeight: height,
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,
    centerTitle: true,

    title: AppText(
      text: title,
      fontSize: 20,
      fontWeight: FontWeight.w600,
    ),

    /// GoRouter Back Button
    leading: canPop
        ? IconButton(
      icon: Icon(
        Icons.arrow_back_outlined,
        color: Colors.black,
        size: 25.r,
      ),
      onPressed: () {
        context.pop(); // GoRouter
      },
    )
        : null,

    actions: [
      if (actionIcon != null)
        Padding(
          padding: EdgeInsets.only(right: 10.w),
          child: IconButton(
            icon: Icon(actionIcon),
            onPressed: onPressedAction,
          ),
        )
    ],

    automaticallyImplyLeading: false,

    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),

    bottom: PreferredSize(
      preferredSize: Size.fromHeight(1.5.h),
      child: Divider(
        height: 1.5.h,
        thickness: 1.5.r,
        color: Colors.grey,
      ),
    ),
  );
}