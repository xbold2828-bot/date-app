import 'package:dating_app/core/constants/static_assets/app_animation.dart';
import 'package:dating_app/core/utils/utils.dart';
import 'package:flutter/material.dart';
import '../../main.dart';

abstract final class AppLoader {
  static OverlayEntry? _overlayEntry;

  /// Pass [overlay] when you already have one (e.g. `Navigator.of(context,
  /// rootNavigator: true).overlay`). Otherwise the root navigator key is used.
  static void show([OverlayState? overlay]) {
    if (_overlayEntry != null) return;

    // navigatorKey.currentContext belongs to the Navigator itself, which sits
    // ABOVE its own Overlay, so Overlay.of(context) can't find one.
    // NavigatorState.overlay is the correct way to reach it.
    final state = overlay ?? navigatorKey.currentState?.overlay;
    if (state == null) return;

    final entry = OverlayEntry(builder: (_) => const LoaderWidget());
    state.insert(entry);
    _overlayEntry = entry;
  }

  static void hide() {
    final entry = _overlayEntry;
    _overlayEntry = null; // clear first so a second call is a no-op
    if (entry == null) return;
    try {
      entry.remove();
    } catch (_) {
      // Already removed (e.g. overlay disposed during navigation).
    }
  }
}

class LoaderWidget extends StatelessWidget {
  const LoaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        color: Colors.white,
        child: staticImage(url: AppAnimation.ringSpinnerGif, w: 200),
      ),
    );
  }
}