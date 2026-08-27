import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

AppBar backButtonAppBar({required BuildContext context}) {
  final canGoBack = Navigator.of(context).canPop();
  final platform = Theme.of(context).platform;

  return AppBar(
    toolbarHeight: canGoBack ? kToolbarHeight : 0,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    elevation: 0,
    scrolledUnderElevation: 0,
    backgroundColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    shadowColor: Colors.transparent,

    /// ✅ Show back button ONLY on mobile
    leading: (canGoBack)
        ? IconButton(
            icon: Icon(
              platform == TargetPlatform.iOS
                  ? Icons.arrow_back_ios
                  : Icons.arrow_back,
              color: Colors.black,
              size: 25.r,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          )
        : null,

    automaticallyImplyLeading: false,
  );
}
