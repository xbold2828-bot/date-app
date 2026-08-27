import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

extension PaddingExtension on Widget {

  /// Padding All
  Widget paddingAll(double value) {
    return Padding(
      padding: EdgeInsets.all(value.w), // or .r (recommended)
      child: this,
    );
  }

  /// Padding Symmetric
  Widget paddingSymmetric({
    double horizontal = 0,
    double vertical = 0,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontal.w,
        vertical: vertical.h,
      ),
      child: this,
    );
  }

  /// Padding Only
  Widget paddingOnly({
    double left = 0,
    double right = 0,
    double top = 0,
    double bottom = 0,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        left: left.w,
        right: right.w,
        top: top.h,
        bottom: bottom.h,
      ),
      child: this,
    );
  }

  /// Padding Horizontal
  Widget paddingHorizontal(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: value.w),
      child: this,
    );
  }

  /// Padding Vertical
  Widget paddingVertical(double value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: value.h),
      child: this,
    );
  }

  /// Padding Left
  Widget paddingLeft(double value) {
    return Padding(
      padding: EdgeInsets.only(left: value.w),
      child: this,
    );
  }

  /// Padding Right
  Widget paddingRight(double value) {
    return Padding(
      padding: EdgeInsets.only(right: value.w),
      child: this,
    );
  }

  /// Padding Top
  Widget paddingTop(double value) {
    return Padding(
      padding: EdgeInsets.only(top: value.h),
      child: this,
    );
  }

  /// Padding Bottom
  Widget paddingBottom(double value) {
    return Padding(
      padding: EdgeInsets.only(bottom: value.h),
      child: this,
    );
  }
}