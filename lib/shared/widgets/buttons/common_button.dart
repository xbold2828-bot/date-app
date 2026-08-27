import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/extensions/padding_extension.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadow.dart';
import '../../../core/utils/utils.dart';
import '../app_text.dart';

class CommonButton extends StatefulWidget {
  final double? height;
  final bool isSmallButton;
  final EdgeInsetsGeometry? internalButtonPadding;
  final bool isLoading;
  final double? spaceBetweenIconAndTitle;
  final double? imageIconSize;
  final double? width;
  final String text;
  final Color? textColor;
  final Color? bgColor;
  final VoidCallback? onClick;
  final bool isDisableButton;
  final FontWeight? fontWeight;
  final String? vectorIcon;
  final IconData? iconData;
  final double? iconDataSize;
  final String? imageIcon;
  final double? buttonRadius;
  final Color iconColor;
  final Gradient? customGradient;
  final bool isGradient;

  const CommonButton({
    super.key,
    this.height,
    this.width,
    this.internalButtonPadding,
    this.spaceBetweenIconAndTitle,
    required this.text,
    this.imageIconSize,
    this.iconData,
    this.imageIcon,
    this.textColor,
    this.bgColor,
    this.vectorIcon,
    this.customGradient,
    this.isLoading = false,
    this.isSmallButton = false,
    this.iconDataSize,
    required this.onClick,
    this.buttonRadius,
    this.fontWeight,
    this.isGradient = true,
    this.iconColor = AppColors.whiteColor,
    this.isDisableButton = false,
  });

  @override
  State<CommonButton> createState() => _CommonButtonState();
}

class _CommonButtonState extends State<CommonButton> {
  bool _isPressed = false;

  // Default gradient colors matching the provided image
  final Color _defaultStartColor = AppColors.secondary;
  final Color _defaultEndColor = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDisabled = widget.isDisableButton;
    final radius = (widget.buttonRadius ?? 8).r;

    // --- Gradient Logic ---
    Color startColor;
    Color endColor;

    if (widget.bgColor != null) {
      // If a color is provided, make the start color 2 shades (~15% lightness) lighter
      endColor = widget.bgColor!;
      final HSLColor hsl = HSLColor.fromColor(endColor);
      startColor = hsl
          .withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0))
          .toColor();
    } else {
      // Default to the dark green gradient from the image
      startColor = _defaultStartColor;
      endColor = _defaultEndColor;
    }

    // Handle pressed state opacity
    if (_isPressed) {
      startColor = startColor.withValues(alpha: 0.8);
      endColor = endColor.withValues(alpha: 0.8);
    }

    return Material(
      color: Colors.transparent, // Must be transparent so Ink gradient shows
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isDisabled
              ? Colors.grey.shade400
              : !widget.isGradient
              ? widget.bgColor
              : null,
          // Only apply gradient if the button is NOT disabled
          gradient: isDisabled || !widget.isGradient
              ? null
              : widget.customGradient ??
                    LinearGradient(
                      colors: [startColor, endColor],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: widget.isLoading || widget.isDisableButton
              ? null
              : widget.onClick,
          onHighlightChanged: (value) {
            if (!isDisabled) {
              setState(() => _isPressed = value);
            }
          },
          child: SizedBox(
            width:
                (widget.width)?.w ??
                (widget.isSmallButton ? null : double.infinity),
            height: (widget.height ?? 50).h,
            child: Padding(
              padding: widget.internalButtonPadding ?? const EdgeInsets.all(0),
              child: Center(
                child: widget.isLoading
                    ? CircularProgressIndicator(color: colorScheme.onPrimary)
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.vectorIcon != null) ...[
                            SvgPicture.asset(
                              widget.vectorIcon!,
                              colorFilter: ColorFilter.mode(
                                widget.iconColor,
                                BlendMode.srcIn,
                              ),
                            ),
                            spacerW(widget.spaceBetweenIconAndTitle ?? 10),
                          ],

                          if (widget.iconData != null) ...[
                            Icon(
                              widget.iconData,
                              size: widget.iconDataSize,
                              color: widget.iconColor,
                            ),
                          ],
                          if (widget.imageIcon != null) ...[
                            staticImage(
                              url: widget.imageIcon!,
                              color: widget.iconColor,
                              w: widget.imageIconSize,
                            ),
                            spacerW(widget.spaceBetweenIconAndTitle ?? 10),
                          ],
                          AppText(
                            text: widget.text,
                            fontSize: 15,
                            isEllipsis: true,
                            color: isDisabled
                                ? Colors.white70
                                : widget.textColor ?? colorScheme.onPrimary,
                            fontWeight: widget.fontWeight ?? FontWeight.w700,
                          ).paddingSymmetric(horizontal: 8.w),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class CommonButton2 extends StatefulWidget {
  final double? height;
  final bool isLoading;
  final double? spaceBetweenIconAndTitle;
  final double? imageIconSize;
  final double? width;
  final String text;
  final Color? textColor;
  final Color? bgColor;
  final VoidCallback? onClick;
  final bool isDisableButton;
  final FontWeight? fontWeight;
  final String? vectorIcon;
  final String? imageIcon;
  final double? buttonRadius;
  final Gradient? customGradient;
  final bool isGradient;
  final Color? label; // unused but kept for compat
  final bool hasShadow;

  const CommonButton2({
    super.key,
    this.height,
    this.width,
    this.spaceBetweenIconAndTitle,
    required this.text,
    this.imageIconSize,
    this.imageIcon,
    this.textColor,
    this.bgColor,
    this.vectorIcon,
    this.customGradient,
    this.isLoading = false,
    required this.onClick,
    this.buttonRadius,
    this.fontWeight,
    this.isGradient = true,
    this.isDisableButton = false,
    this.label,
    this.hasShadow = true,
  });

  @override
  State<CommonButton2> createState() => _CommonButton2State();
}

class _CommonButton2State extends State<CommonButton2>
    with SingleTickerProviderStateMixin {
  bool _isPressed = false;
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnim = Tween<double>(
      begin: 1.0,
      end: 0.97,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = widget.isDisableButton;
    final radius = (widget.buttonRadius ?? 14).r;

    Color startColor, endColor;
    if (widget.bgColor != null) {
      endColor = widget.bgColor!;
      final hsl = HSLColor.fromColor(endColor);
      startColor = hsl
          .withLightness((hsl.lightness + 0.12).clamp(0.0, 1.0))
          .toColor();
    } else {
      startColor = AppColors.secondary;
      endColor = AppColors.secondaryDark;
    }

    if (_isPressed) {
      startColor = startColor.withValues(alpha: 0.85);
      endColor = endColor.withValues(alpha: 0.85);
    }

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: (isDisabled || !widget.hasShadow)
              ? null
              : AppShadow.button,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: isDisabled
                  ? Colors.grey.shade400
                  : (!widget.isGradient ? widget.bgColor : null),
              gradient: isDisabled || !widget.isGradient
                  ? null
                  : widget.customGradient ??
                        LinearGradient(
                          colors: [startColor, endColor],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: widget.isLoading || isDisabled ? null : widget.onClick,
              onHighlightChanged: (v) {
                if (!isDisabled) {
                  setState(() => _isPressed = v);
                  if (v) {
                    _ctrl.forward();
                  } else {
                    _ctrl.reverse();
                  }
                }
              },
              child: SizedBox(
                width: (widget.width)?.w ?? double.infinity,
                height: (widget.height ?? 52).h,
                child: Center(
                  child: widget.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (widget.vectorIcon != null) ...[
                              SvgPicture.asset(widget.vectorIcon!),
                              SizedBox(
                                width:
                                    widget.spaceBetweenIconAndTitle?.w ?? 10.w,
                              ),
                            ],
                            if (widget.imageIcon != null) ...[
                              staticImage(
                                url: widget.imageIcon!,
                                w: widget.imageIconSize,
                              ),
                              SizedBox(
                                width:
                                    widget.spaceBetweenIconAndTitle?.w ?? 10.w,
                              ),
                            ],
                            AppText(
                              text: widget.text,
                              fontSize: 15,
                              isEllipsis: true,
                              color: isDisabled
                                  ? Colors.white70
                                  : widget.textColor ?? Colors.white,
                              fontWeight: widget.fontWeight ?? FontWeight.w700,
                              letterSpacing: 0.2,
                            ).paddingSymmetric(horizontal: 8.w),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
