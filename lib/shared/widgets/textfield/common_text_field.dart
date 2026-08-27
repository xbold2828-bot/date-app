import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_styles.dart';

class CommonTextField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final List<TextInputFormatter>? inputFormatters;

  // Text
  final String? hintText;
  final bool? isDense;
  final String? labelText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final int maxLines;
  final int? maxLength;
  final bool readOnly;
  final bool enabled;
  final int? minLines;
  final bool isMaxMinSame;

  // Obscure
  final bool isPassword;

  final bool isSuffixClickableOnDisable;

  // Validation & callbacks
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final VoidCallback? onTap;

  // Icons
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final Color? enableBorderColor;

  // ✅ ADDED: AutovalidateMode
  final AutovalidateMode? autoValidateMode;

  // Styling
  final TextStyle? textStyle;
  final InputBorder? border;
  final EdgeInsetsGeometry? contentPadding;
  final Color? fillColor;
  final bool filled;
  final bool isDropDown;
  final Color? hintTextColor;
  final TextAlign textAlign;

  const CommonTextField({
    super.key,
    this.isDense,
    this.isSuffixClickableOnDisable = false,
    this.inputFormatters,
    required this.controller,
    this.hintText,
    this.textAlign = TextAlign.start,
    this.focusNode,
    this.labelText,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.isDropDown = false,
    this.isMaxMinSame = true,
    this.autoValidateMode = AutovalidateMode.onUserInteraction,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.readOnly = false,
    this.enabled = true,
    this.isPassword = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.onTap,
    this.prefixIcon,
    this.suffixIcon,
    this.textStyle,
    this.border,
    this.contentPadding,
    this.fillColor,
    this.filled = true,
    this.hintTextColor,
    this.enableBorderColor,
  });

  @override
  State<CommonTextField> createState() => _CommonTextFieldState();
}

class _CommonTextFieldState extends State<CommonTextField> {
  late bool _obscureText;

  // Create a FocusNode that completely blocks focus
  late FocusNode _disabledFocusNode;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
    _disabledFocusNode = FocusNode(canRequestFocus: false);
  }

  @override
  void dispose() {
    _disabledFocusNode.dispose();
    super.dispose();
  }

  // Small helper so every border we build shares the same radius/shape
  // and we don't duplicate the OutlineInputBorder(...) boilerplate.
  OutlineInputBorder _outlineBorder({
    required Color borderColor,
    required double width,
  }) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(8.r),
      borderSide: BorderSide(width: width, color: borderColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = !widget.enabled;
    final bool forceEnabledForSuffix =
        isDisabled && widget.isSuffixClickableOnDisable;

    final color =
        widget.enableBorderColor ??
        AppColors.blackColor.withValues(alpha: 0.15);
    const selectedColor = AppColors.greyColor;
    final hintColor =
        widget.hintTextColor ?? AppColors.surface.withValues(alpha: 0.6);
    final iconColor = AppColors.blackColor.withValues(alpha: 0.38);
    final styleColor = AppColors.blackColor.withValues(alpha: 0.87);

    // Disabled border to force the visual "faked disabled" state.
    final disabledBorderObj = _outlineBorder(
      borderColor: const Color(0x00d1d5db),
      width: 1.5.r,
    );

    // ---------------------------------------------------------------
    // ✅ FIX: previously, `widget.enableBorderColor` was baked into a
    // local `color` variable that only got used *inside* the
    // `widget.border ?? OutlineInputBorder(...)` fallback. That meant
    // as soon as a caller supplied a custom `border`, `enableBorderColor`
    // was silently ignored — even though the parameter name promises it
    // controls the enabled-state border color.
    //
    // Now `enableBorderColor` is resolved first and always takes
    // priority for the enabled (non-focused) border, regardless of
    // whether a custom `border` was also passed. If no custom border
    // and no enableBorderColor are supplied, we fall back to the
    // original default grey border.
    // ---------------------------------------------------------------
    final InputBorder resolvedEnabledBorder = widget.enableBorderColor != null
        ? _outlineBorder(borderColor: widget.enableBorderColor!, width: 1.r)
        : (widget.border ?? _outlineBorder(borderColor: color, width: 1.r));

    final InputBorder resolvedBaseBorder = resolvedEnabledBorder;

    // Focus state stays visually distinct (uses selectedColor) unless the
    // caller explicitly passed a custom `border` to override everything.
    final InputBorder resolvedFocusedBorder =
        widget.border ??
        _outlineBorder(borderColor: selectedColor, width: 1.5.r);

    return TextFormField(
      textAlign: widget.textAlign,
      autovalidateMode: widget.autoValidateMode,
      inputFormatters: widget.inputFormatters,
      controller: widget.controller,
      keyboardType: widget.keyboardType,
      // contextMenuBuilder: (context, editableTextState) {
      //   return AdaptiveTextSelectionToolbar(
      //     anchors: editableTextState.contextMenuAnchors,
      //     children: [
      //       TextButton(
      //         onPressed: () {
      //           editableTextState.cutSelection(SelectionChangedCause.toolbar);
      //         },
      //         child: Text("Cut", style: TextStyle(color: toolbarTextColor)),
      //       ),
      //       TextButton(
      //         onPressed: () {
      //           editableTextState.copySelection(SelectionChangedCause.toolbar);
      //         },
      //         child: Text("Copy", style: TextStyle(color: toolbarTextColor)),
      //       ),
      //       TextButton(
      //         onPressed: () {
      //           editableTextState.pasteText(SelectionChangedCause.toolbar);
      //         },
      //         child: Text("Paste", style: TextStyle(color: toolbarTextColor)),
      //       ),
      //       TextButton(
      //         onPressed: () {
      //           editableTextState.selectAll(SelectionChangedCause.toolbar);
      //         },
      //         child: Text("Select All", style: TextStyle(color: toolbarTextColor)),
      //       ),
      //       spacerW(8),
      //     ],
      //   );
      // },
      textInputAction: widget.textInputAction,
      maxLines: widget.isPassword ? 1 : widget.maxLines,
      minLines: widget.isMaxMinSame ? widget.maxLines : (widget.minLines ?? 1),
      maxLength: widget.maxLength,

      enabled: forceEnabledForSuffix ? true : widget.enabled,
      readOnly: forceEnabledForSuffix ? true : widget.readOnly,
      enableInteractiveSelection: forceEnabledForSuffix ? false : true,

      // Prevent the field from receiving focus if we are faking the
      // enabled state.
      focusNode: forceEnabledForSuffix ? _disabledFocusNode : widget.focusNode,

      obscureText: _obscureText,
      style: isDisabled
          ? context.appTextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: styleColor,
            )
          : widget.textStyle ??
                (widget.isDropDown
                    ? context.appTextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: styleColor,
                      )
                    : null),
      enableSuggestions: !widget.isPassword,
      autocorrect: !widget.isPassword,
      validator: (value) {
        if (!widget.enabled) return null; // skip validation when disabled
        return widget.validator?.call(value);
      },
      onChanged: widget.onChanged,
      onFieldSubmitted: widget.onFieldSubmitted,

      // Block onTap from firing when disabled.
      onTap: forceEnabledForSuffix ? null : widget.onTap,

      decoration: InputDecoration(
        isDense: widget.isDense,
        contentPadding:
            widget.contentPadding ??
            EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 10.h),
        hintStyle: context.appTextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: hintColor,
        ),
        hintText: widget.hintText,
        labelText: widget.labelText,
        labelStyle: context.appTextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: hintColor,
        ),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.isPassword
            ? IconButton(
                icon: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.14159),
                    child: Icon(
                      _obscureText
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: iconColor,
                    ),
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _obscureText = !_obscureText;
                  });
                },
              )
            : widget.suffixIcon,
        filled: isDisabled ? true : widget.filled,
        fillColor: isDisabled
            ? AppColors.tertiary.withValues(alpha: 0.10)
            : widget.fillColor,

        // Explicitly swap the borders so they appear disabled when the
        // "clickable while disabled" mode is active — otherwise use the
        // properly-resolved borders above, which now correctly respect
        // `enableBorderColor`.
        border: forceEnabledForSuffix ? disabledBorderObj : resolvedBaseBorder,
        enabledBorder: forceEnabledForSuffix
            ? disabledBorderObj
            : resolvedEnabledBorder,
        focusedBorder: forceEnabledForSuffix
            ? disabledBorderObj
            : resolvedFocusedBorder,
        disabledBorder: disabledBorderObj,
      ),
    );
  }
}
