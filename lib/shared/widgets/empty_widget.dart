import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../core/constants/app_text_styles.dart';
import '../../core/constants/static_assets/app_animation.dart';
import '../../core/extensions/padding_extension.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/utils.dart';
import 'buttons/common_button.dart';

class EmptyWidget extends StatelessWidget {
  final bool isLikePage;
  const EmptyWidget({super.key,
    this.title,
     this.body,
    this.actionLabel,
    this.onAction,
    this.isLikePage=false,
  });

  final String? title;
  final String? body;

  /// Optional call-to-action, e.g. "Refresh" or "Update filters".
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // One-shot entrance animation (fade + slide up). No controller needed.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 24 * (1 - t)),
          child: child,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 48, 32, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GlowOrb(isLikePage: isLikePage),
            if (title != null) ...[
            spacerH(28),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: AppTextStyles.title.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                height: 1.2,
                letterSpacing: -0.3,
              ),
            ),
            ],

            if(body!=null) ...[
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                body!,
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textGrey,
                ),
              ),
            ),

            ],
            if (actionLabel != null && onAction != null) ...[
              spacerH(28),
              SizedBox(
                width: 200,
                child: CommonButton(
                  text: actionLabel!,
                  isLoading: false,
                  onClick: onAction,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final bool isLikePage;
  const _GlowOrb({this.isLikePage=false});

  /// Fine-tune the GIF position. Offset(0, 0) = exact center.
  /// e.g. Offset(-4, 0) moves it 4px left, Offset(0, 6) moves it 6px down.
  static const Offset _gifNudge = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final size = 250.w.clamp(200.0, 290.0).toDouble();
    final gifSize = size * 0.82;

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ambient glow – fades smoothly into the background.
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.textGrey.withValues(alpha: 0.16),
                    AppColors.textGrey.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
              child: SizedBox(width: size, height: size),
            ),

            // 2. Faint concentric rings, fading outward.
            CustomPaint(
              size: Size(size, size),
              painter: _RingsPainter(color: AppColors.inputBorder),
            ),

            // 3. Radar GIF with feathered (masked) edges.
            ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => const RadialGradient(
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.55, 1.0], // 0.55 = where the fade begins
              ).createShader(rect),
              child: SizedBox(
                width: gifSize,
                height: gifSize,
                child: Center(
                  // If the radar still looks off-center, the GIF file itself
                  // has uneven padding – nudge it here (x, y in logical px).
                  child: Transform.translate(
                    offset: _gifNudge,
                    child: staticImage(
                      url: isLikePage? AppAnimation.likeMatchGif :AppAnimation.radarGif,
                      h: gifSize,
                    ).paddingOnly(bottom: isLikePage ? 0: 20.h),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;

    // Inner -> outer, each ring a little fainter (darker than before).
    const radii = [0.45, 0.70, 0.95];
    const alphas = [0.95, 0.70, 0.45]; // was [0.55, 0.35, 0.18]

    for (var i = 0; i < radii.length; i++) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 // was 1
        ..color = color.withValues(alpha: alphas[i]);
      canvas.drawCircle(center, maxRadius * radii[i], paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.color != color;
}