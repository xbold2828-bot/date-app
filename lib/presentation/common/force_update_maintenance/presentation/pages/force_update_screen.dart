import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/app_constants.dart';
import '../../../../../core/constants/app_string.dart';
import '../../../../../core/extensions/global_back_extension.dart';
import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/utils/app_snack_bar.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../shared/widgets/app_text.dart';
import '../../../../../shared/widgets/buttons/common_button.dart';

class ForceUpdateScreen extends StatelessWidget {
  const ForceUpdateScreen({super.key});

  final List<String> improvements = const [
    "Performance optimizations for a smoother experience",
    "Access to the latest features and platform capabilities",
    "Critical security enhancements and data protection patches",
    "General bug fixes and stability improvements",
  ];

  Future<void> _launchAppStore() async {
    Uri storeUrl;
    if (Platform.isAndroid) {
      storeUrl = Uri.parse(
        "https://play.google.com/store/apps/details?id=${AppConstants.androidAppId}",
      );
    } else if (Platform.isIOS) {
      storeUrl = Uri.parse(
        "https://apps.apple.com/app/${AppConstants.iosAppId}",
      );
    } else {
      AppSnackBar.showErrorSnackBar(
        title: "Error",
        message: "Unsupported Platform",
      );
      return;
    }

    await openUrl(isExternal: true, url: storeUrl.toString());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.whiteColor,
      // 1. --- THE BULLETPROOF STATUS BAR HACK ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(0.0), // Invisible AppBar
        child: AppBar(
          backgroundColor: Colors.black, // Ensures the background matches
          elevation: 0,
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.black, // Android: Black background
            statusBarIconBrightness: Brightness.light, // Android: White icons
            statusBarBrightness: Brightness.dark, // iOS: White icons
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                // --- Decorative Background Accent ---
                Positioned(
                  top: -50.h,
                  right: -30.w,
                  child: Container(
                    width: 150.r,
                    height: 150.r,
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),

                // --- Main Content Layout ---
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        spacerH(50),

                        // 1. --- APP UPDATE ACCENT ICON ---
                        Container(
                          padding: EdgeInsets.all(30.r),
                          decoration: BoxDecoration(
                            color: AppColors.secondary.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.system_update_alt_rounded,
                            size: 100.r,
                            color: AppColors.secondary,
                          ),
                        ),

                        spacerH(30),

                        // 2. --- EXCITING TITLE ---
                        const AppText(
                          text: AppString.forceUpdateTitle,
                          textAlign: TextAlign.center,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),

                        spacerH(12),

                        // 3. --- EXPLANATORY SUBTITLE ---
                        const AppText(
                          text: AppString.forceUpdateSubTitle,
                          textAlign: TextAlign.center,
                          fontSize: 15,
                          fontWeight: FontWeight.normal,
                          color: AppColors.textSecondary,
                        ),

                        spacerH(25),

                        // 4. --- GENERIC WHAT'S NEW CARD ---
                        Container(
                          padding: EdgeInsets.all(20.r),
                          decoration: BoxDecoration(
                            color: AppColors.whiteColor,
                            borderRadius: BorderRadius.circular(16.r),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText(
                                text: AppString.whatsNew,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              spacerH(12),

                              ...improvements.map(
                                (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsets.only(top: 2.h),
                                        child: const Icon(
                                          Icons.check_circle_rounded,
                                          color: AppColors.secondary,
                                          size: 16,
                                        ),
                                      ),
                                      spacerW(12),
                                      Expanded(
                                        child: AppText(
                                          text: item,
                                          fontSize: 14,
                                          color: AppColors.greyColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        spacerH(40),

                        // 5. --- ACTION CTA ---
                        CommonButton(
                          text: AppString.updateNow,
                          onClick: _launchAppStore,
                        ),

                        spacerH(60),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ).withGlobalBackHandler(context);
  }
}
