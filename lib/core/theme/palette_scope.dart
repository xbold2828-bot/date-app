import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Keeps [AppColors] pointed at the palette for the theme currently in force.
///
/// Sits inside `MaterialApp.builder`, above every screen, so the swap happens
/// before anything that reads a token builds.
///
/// ## Why the rebuild sweep
///
/// Screens read colours as plain statics — `AppColors.card`, not
/// `Theme.of(context).colorScheme.surface`. That is what keeps 700-odd call
/// sites readable, and it is also why Flutter cannot know they are stale: a
/// widget that never touched an [InheritedWidget] has no dependency to
/// invalidate, so a plain `Container(color: AppColors.card)` would keep its old
/// colour until something else happened to rebuild it. The result is a
/// half-swapped screen.
///
/// So on an actual change of brightness — not on every build — every element
/// below this one is marked dirty for one frame. [State] objects are untouched,
/// which is the point: the navigation stack, scroll positions, open sheets and
/// in-flight requests all survive; only `build` runs again.
class PaletteScope extends StatefulWidget {
  const PaletteScope({super.key, required this.child});

  final Widget child;

  @override
  State<PaletteScope> createState() => _PaletteScopeState();
}

class _PaletteScopeState extends State<PaletteScope> {
  /// False until the first build has settled the palette.
  ///
  /// Launching on a phone already in dark mode is a change of palette with
  /// nothing below it yet — everything is about to build for the first time,
  /// and it will build dark. Sweeping there would only mark a tree that is
  /// already correct, on the one frame of the app's life that can least afford
  /// it.
  bool _settled = false;

  @override
  Widget build(BuildContext context) {
    final changed = AppColors.use(Theme.of(context).brightness);
    if (changed && _settled) {
      // Everything built from here down in *this* frame already picks up the
      // new palette. The sweep is for the elements Flutter had no reason to
      // rebuild, so it can wait for the frame to finish.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _rebuildSubtree(context);
      });
    }
    _settled = true;
    return widget.child;
  }

  static void _rebuildSubtree(BuildContext context) {
    void visit(Element element) {
      element.markNeedsBuild();
      element.visitChildren(visit);
    }

    (context as Element).visitChildren(visit);
  }
}
