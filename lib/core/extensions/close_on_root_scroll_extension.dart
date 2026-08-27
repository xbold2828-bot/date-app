import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

extension CloseOnRootScrollExtension on Widget {
  Widget closeOnRootScroll(BuildContext context) {
    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        final isKeyboardOpen =
            MediaQuery.of(context).viewInsets.bottom > 0;

        if (!isKeyboardOpen &&
            notification.depth == 0 &&
            notification.direction != ScrollDirection.idle) {
          FocusScope.of(context).unfocus();
        }

        return false;
      },
      child: this,
    );
  }
}
