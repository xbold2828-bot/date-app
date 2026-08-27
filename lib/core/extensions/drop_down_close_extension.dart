import 'package:flutter/material.dart';

extension SearchScrollExtension on Widget {
  Widget closeSearchOnScroll({double height = 20}) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final double appBarHeight = kToolbarHeight + height;
          final BuildContext? focusedContext = FocusManager.instance.primaryFocus?.context;

          if (focusedContext != null) {
            final RenderBox? renderBox = focusedContext.findRenderObject() as RenderBox?;

            if (renderBox != null) {
              final double fieldTopY = renderBox.localToGlobal(Offset.zero).dy;
              if (fieldTopY <= appBarHeight) {
                FocusManager.instance.primaryFocus?.unfocus();
              }
            }
          }
        }
        return false;
      },
      child: this,
    );
  }
}