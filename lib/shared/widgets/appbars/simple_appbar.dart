import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/constants/static_assets/app_icons.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradient.dart';
import '../../../core/utils/utils.dart';

class SimpleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final bool isEffects;
  final bool showBackButton;

  const SimpleAppBar({
    super.key,
    this.isEffects = true,
    this.showBackButton=true
  });

  @override
  Size get preferredSize => Size.fromHeight(116.h);

  @override
  Widget build(BuildContext context) {

    final canGoBack = Navigator.of(context).canPop() && showBackButton;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:isEffects? Brightness.light :Brightness.dark,  // Android
        statusBarBrightness: isEffects? Brightness.dark :Brightness.light,  // iOS
      ),
      child: PreferredSize(
      preferredSize: Size.fromHeight(116.h),
      child:  Container(
          width: double.infinity,
          height: 116.h,
          decoration: isEffects? BoxDecoration(
            color: isEffects==false?AppColors.whiteColor:null,
            gradient: AppGradient.darkGreenRadial(),
          ):null,

          alignment: Alignment.center,
          child: SafeArea(
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: canGoBack ? Padding(
                    padding: EdgeInsets.only(left: 10.w),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_outlined,
                        color: AppColors.whiteColor, // change if needed
                        size: 30.r,
                      ),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                      },
                    ),
                  ): const SizedBox.shrink(),
                ),


                Align(
                  alignment: Alignment.center,
                  child: staticImage(url: AppIcons.appLogo,color: isEffects? Colors.white:Colors.black),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}