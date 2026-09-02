import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../../core/constants/static_assets/app_icons.dart';
import '../../../../../core/extensions/global_back_extension.dart';
import '../../../../../core/utils/utils.dart';
import '../../../../../shared/widgets/app_text.dart';
import '../../../../../shared/widgets/buttons/common_button.dart';

class MaintenancePage extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onRefresh;

  const MaintenancePage({
    super.key,
    this.title = "We're upgrading\nour systems",
    required this.message,
    required this.onRefresh,
  });

  @override
  State<MaintenancePage> createState() => _MaintenancePageState();
}

class _MaintenancePageState extends State<MaintenancePage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Android
        statusBarBrightness: Brightness.light, // iOS
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        body: Stack(
          children: [
            // ── DECORATIVE BACKGROUND BLOBS ──
            Positioned(
              top: -80.h,
              right: -60.w,
              child: Container(
                width: 260.w,
                height: 260.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 60.h,
              left: -80.w,
              child: Container(
                width: 200.w,
                height: 200.w,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // ── MAIN CONTENT ──
            SafeArea(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 28.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // ── ANIMATED ICON CLUSTER ──
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulseAnimation.value,
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 136.w,
                            height: 136.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.15),
                                  const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.04),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                          // Mid ring
                          Container(
                            width: 108.w,
                            height: 108.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.18),
                                width: 1.5,
                              ),
                            ),
                          ),
                          // Icon container
                          Container(
                            width: 88.w,
                            height: 88.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.20),
                                  blurRadius: 24,
                                  spreadRadius: 2,
                                  offset: const Offset(0, 6),
                                ),
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  blurRadius: 8,
                                  spreadRadius: -2,
                                  offset: const Offset(0, -2),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                AppIcons.appLogo,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    spacerH(40),

                    // ── STATUS PILL ──
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 7.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2FF),
                        borderRadius: BorderRadius.circular(100.r),
                        border: Border.all(
                          color: const Color(
                            0xFF6366F1,
                          ).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 7.w,
                            height: 7.w,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF6366F1),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF6366F1,
                                  ).withValues(alpha: 0.5),
                                  blurRadius: 5,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                          ),
                          spacerW(8),
                          const AppText(
                            text: 'Maintenance in Progress',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4F46E5),
                            letterSpacing: 0.2,
                          ),
                        ],
                      ),
                    ),

                    spacerH(24),

                    // ── TITLE ──
                    AppText(
                      text: widget.title,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      textAlign: TextAlign.center,
                      height: 1.3,
                      letterSpacing: -0.6,
                    ),

                    spacerH(16),

                    // ── MESSAGE ──
                    AppText(
                      text: widget.message,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF64748B),
                      textAlign: TextAlign.center,
                      height: 1.65,
                    ),

                    spacerH(48),

                    // ── DIVIDER WITH LABEL ──
                    Row(
                      children: [
                        const Expanded(child: Divider(thickness: 1)),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: const AppText(
                            text: 'Ready when you are',
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Expanded(child: Divider(thickness: 1)),
                      ],
                    ),

                    spacerH(24),

                    // ── REFRESH BUTTON ──
                    CommonButton(
                      text: 'Check Again',
                      onClick: widget.onRefresh,
                    ),

                    spacerH(20),

                    // ── SUBTLE FOOTER NOTE ──
                    const AppText(
                      text: 'We appreciate your patience',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).withGlobalBackHandler(context);
  }
}
