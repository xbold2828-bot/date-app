import 'package:flutter/material.dart';

/// iOS scrolling on every platform.
///
/// Lists rubber-band at their ends: past an edge the content keeps following
/// the finger with growing resistance, then springs back. A hard stop — or
/// Android's glow and stretch — reads as the list having frozen; resistance
/// reads as "responsive, but there is nothing more here".
///
/// Scrollables that set their own `physics` keep them.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: RangeMaintainingScrollPhysics());

  /// The bounce is the overscroll feedback, so the glow and stretch go.
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child;
}
