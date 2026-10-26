import 'package:flutter/widgets.dart';

/// The spacing scale: a 4-point grid that grows with the reader's text size.
///
/// ## Why not screen size
///
/// Spacing used to scale with the screen through ScreenUtil — every gap was a
/// fraction of the device's height or width. Apple's layouts do the opposite.
/// Margins are fixed points, chosen by size class, and the thing that grows
/// is the *text*: when someone turns their text size up, the gaps between
/// lines and blocks grow with it so the page does not turn into a wall. A
/// screen that is merely taller gets more content, not bigger gaps.
///
/// So [factor] follows the text-size setting and nothing else. It grows at
/// half the rate of the text — whitespace that kept pace with 300% type would
/// leave no room for the type — and never shrinks below the design values.
///
/// ## Use
///
/// Prefer the named steps. [scaled] exists for the values that sit off the
/// grid for a reason — a hairline gap, a measured optical correction — and
/// for the `spacerH` / `paddingAll` helpers, which pass their argument through
/// it.
///
/// Values are read as plain statics, like `AppColors`, so [SpacingScope]
/// keeps them current and re-runs `build` below it when they change.
abstract final class AppSpacing {
  static double _factor = 1;
  static bool _wide = false;

  /// How much spacing grows with the reader's text size. `1` at the default.
  static double get factor => _factor;

  /// [points] on the design grid, grown with the reader's text size.
  static double scaled(double points) => points * _factor;

  static double get xxs => scaled(4);
  static double get xs => scaled(8);
  static double get sm => scaled(12);
  static double get md => scaled(16);
  static double get lg => scaled(20);
  static double get xl => scaled(24);
  static double get xxl => scaled(32);
  static double get xxxl => scaled(40);
  static double get huge => scaled(48);

  /// A screen's side margin — Apple's layout margins: 16pt on compact
  /// phones, 20pt on the wide ones.
  static double get screenMargin => scaled(_wide ? 20 : 16);

  /// Horizontal padding by [screenMargin], for a screen's main column.
  static EdgeInsets get screen => EdgeInsets.symmetric(horizontal: screenMargin);

  /// The smallest touch target Apple allows, in points. A control can look
  /// smaller, but the area that responds to a finger cannot.
  static const double minTarget = 44;

  /// From this width a phone is "wide" and gets the larger margin.
  static const double wideWidth = 414;

  /// Re-derives the scale from the current text size and screen width.
  ///
  /// Returns true when anything changed.
  static bool update({required TextScaler textScaler, required double width}) {
    // How far the platform scales Body (17pt) — the same reading HigTextScaler
    // takes, so spacing and type move together.
    final textRatio = textScaler.scale(17) / 17;
    final factor = (1 + (textRatio - 1) * 0.5).clamp(1.0, 1.5);
    final wide = width >= wideWidth;

    final changed = factor != _factor || wide != _wide;
    _factor = factor;
    _wide = wide;
    return changed;
  }

  /// Puts the scale back to the design values. For tests.
  @visibleForTesting
  static void reset() {
    _factor = 1;
    _wide = false;
  }
}

/// Keeps [AppSpacing] in step with the text size and screen width.
///
/// Works exactly like `PaletteScope`, for the same reason: spacing is read as
/// plain statics, so a widget that used `AppSpacing.md` has no dependency for
/// Flutter to invalidate. On an actual change — someone turning their text
/// size up with the app open, or rotating onto a wide layout — every element
/// below is marked dirty for one frame. State, scroll positions and the
/// navigation stack survive; only `build` runs again.
class SpacingScope extends StatefulWidget {
  const SpacingScope({super.key, required this.child});

  final Widget child;

  @override
  State<SpacingScope> createState() => _SpacingScopeState();
}

class _SpacingScopeState extends State<SpacingScope> {
  /// False until the first build has settled the scale — the very first one
  /// is not a change, everything below is about to build for the first time.
  bool _settled = false;

  @override
  Widget build(BuildContext context) {
    final changed = AppSpacing.update(
      textScaler: MediaQuery.textScalerOf(context),
      width: MediaQuery.sizeOf(context).width,
    );
    if (changed && _settled) {
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
