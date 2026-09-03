import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

abstract final class NavigationHelper {

  static bool canGoBack(BuildContext context) {
    return context.canPop(); // GoRouter method
  }

  static bool isRoot(BuildContext context) {
    return !context.canPop(); // opposite
  }
}