import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import '../../../core/extensions/padding_extension.dart';
import '../../../core/theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bool isDisabled = widget.isDisableButton;
    final radius = (widget.buttonRadius ?? 16).r;

    // One solid fill. The teal-to-blue sweep this used to paint belonged to
    // no part of the palette and made every legacy screen look templated.
    // `isGradient` and `customGradient` survive for callers that still pass
    // them; only an explicit gradient paints one.
    var fill = widget.bgColor ?? AppColors.primary;
    if (_isPressed) fill = Color.alphaBlend(Colors.black.withValues(alpha: 0.08), fill);

    return Material(
      color: Colors.transparent, // Must be transparent so Ink gradient shows
      borderRadius: BorderRadius.circular(radius),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: isDisabled
              ? AppColors.inputBorder
              : (widget.customGradient == null ? fill : null),
          gradient: isDisabled ? null : widget.customGradient,
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
            height: (widget.height ?? 54).h,
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
                          // Flexible, or `isEllipsis` never gets the chance:
                          // a Row hands its children unbounded width, so a
                          // long label at a large text size pushed past the
                          // button's edge instead of truncating.
                          Flexible(
                            child: AppText(
                              text: widget.text,
                              fontSize: 15,
                              isEllipsis: true,
                              color: isDisabled
                                  ? AppColors.textGrey
                                  : widget.textColor ?? AppColors.onAccent,
                              fontWeight: widget.fontWeight ?? FontWeight.w700,
                            ).paddingSymmetric(horizontal: 8.w),
                          ),
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

    var fill = widget.bgColor ?? AppColors.primary;
    if (_isPressed) fill = Color.alphaBlend(Colors.black.withValues(alpha: 0.08), fill);

    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (_, child) =>
          Transform.scale(scale: _scaleAnim.value, child: child),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          // Flat, like every other button in the app.
          boxShadow: null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              color: isDisabled
                  ? AppColors.inputBorder
                  : (widget.customGradient == null ? fill : null),
              gradient: isDisabled ? null : widget.customGradient,
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
