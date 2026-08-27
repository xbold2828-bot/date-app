import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../main.dart';
import '../constants/static_assets/app_icons.dart';

abstract final class AppLoader {
  static OverlayEntry? _overlayEntry;

  static void show() {
    if (_overlayEntry != null) return;
    final context = navigatorKey.currentContext; // ← use navigatorKey
    if (context == null) return;

    _overlayEntry = OverlayEntry(builder: (_) => const LoaderWidget());
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  static void hide() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class LoaderWidget extends StatefulWidget {
  const LoaderWidget({super.key});

  @override
  State<LoaderWidget> createState() => _LoaderWidgetState();
}

class _LoaderWidgetState extends State<LoaderWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 65.h,
        width: 65.w,
        child: Stack(
          alignment: Alignment.center,
          children: [
            /// 🔄 Rotating Border Layer (Bottom)
            RotationTransition(
              turns: _controller,
              child: Container(
                decoration: const BoxDecoration(
                  // Using circle to perfectly match the CircleAvatar.
                  // If you want squircle borders, change this back to:
                  // borderRadius: BorderRadius.circular(14.r)
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      Colors.transparent,
                      Colors.white, // Or AppColors.primary
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            /// 🔒 Static Inner Container Layer (Top)
            Container(
              // The margin dictates the thickness of the rotating border
              margin: EdgeInsets.all(3.r),
              decoration: BoxDecoration(
                // This color masks the center of the gradient so it looks like a ring.
                // Set this to your app's background color (e.g., Colors.black, Colors.white)
                color: Theme.of(context).scaffoldBackgroundColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.transparent,
                // Make sure AppIcons.loaderIcon is properly imported/defined
                backgroundImage: const AssetImage(
                  AppIcons.roundedLauncherIconNoBg,
                ), // Replace with AppIcons.loaderIcon
              ),
            ),
          ],
        ),
      ),
    );
  }
}
