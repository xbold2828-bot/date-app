import 'package:flutter/material.dart';

extension UnfocusOnTapExtension on Widget {
  Widget unfocusOnTap({
    HitTestBehavior behavior = HitTestBehavior.translucent,
  }) {
    return GestureDetector(
      behavior: behavior,
      onTap: () {
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: this,
    );
  }
}