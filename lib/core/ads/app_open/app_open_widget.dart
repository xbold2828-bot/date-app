import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_open_ad_provider.dart';

/// Keeps [AppOpenAdController] alive and optionally triggers a show check.
///
/// Place near the root of your widget tree (e.g. wrapping `MaterialApp`,
/// or on your splash/home screen) so the controller is built and its
/// lifecycle observer is registered.
///
/// Usage:
/// ```dart
/// // Wrap once near the app root to keep the controller alive:
/// AppOpenAdWidget(child: MaterialApp(...))
///
/// // Or, to show right after cold-start splash finishes loading:
/// AppOpenAdWidget(
///   showOnInit: true,
///   child: HomeScreen(),
/// )
/// ```
class AppOpenAdWidget extends ConsumerStatefulWidget {
  const AppOpenAdWidget({
    super.key,
    required this.child,
    this.showOnInit = false,
  });

  final Widget child;

  /// If true, attempts to show an app open ad once, right after this
  /// widget's first frame. Use this on the screen you land on after a
  /// cold start, since `AppLifecycleState.resumed` doesn't fire then.
  final bool showOnInit;

  @override
  ConsumerState<AppOpenAdWidget> createState() => _AppOpenAdWidgetState();
}

class _AppOpenAdWidgetState extends ConsumerState<AppOpenAdWidget> {
  @override
  void initState() {
    super.initState();
    if (widget.showOnInit) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref.read(appOpenAdControllerProvider.notifier).showAdIfEligible();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watching keeps the Notifier alive for as long as this widget is
    // mounted, so the WidgetsBindingObserver stays registered.
    ref.watch(appOpenAdControllerProvider);
    return widget.child;
  }
}