import 'package:flutter/physics.dart';
import 'package:flutter/widgets.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/utils/app_haptics.dart';

/// How a [Pressable] shows that a finger is on it.
enum PressFeedback {
  /// Shrinks slightly. Buttons, cards, photos — anything with a body.
  scale,

  /// Fades. Text links and bare icons — things with no body to shrink.
  dim,

  /// Tints over the content. Rows in a list.
  highlight,

  /// Nothing visual, for a child that draws its own pressed state.
  none,
}

/// The app's tap target: feedback on touch-down, action on touch-up.
///
/// ## When things happen
///
/// - **The finger lands** → the pressed state shows on that frame, with no
///   fade-in. (Inside a scrolling list Flutter holds it for up to 100ms first,
///   so starting a scroll does not flash every row the finger crosses — iOS
///   does the same.)
/// - **The finger lifts** → [onTap] runs, and the pressed state springs back
///   from wherever it is.
/// - **The finger slides off** → the tap cancels. Nothing runs.
///
/// The action deliberately waits for the lift. Running it on touch-down would
/// make scrolling open whatever the finger happened to land on, and would take
/// away the one way people back out of a tap they did not mean.
///
/// A quick tap still shows its feedback: the press is applied in full the
/// moment it registers, so even a tap that lands and lifts within one frame
/// flashes, then fades.
///
/// ## Interruptible
///
/// Pressing again while it is still springing back jumps straight to pressed,
/// and every release starts from the value and velocity on screen. There is
/// no animation to wait for.
///
/// ## Everything else it keeps
///
/// - Keyboard and switch access: it takes focus, draws a focus ring, and
///   Enter/Space activate it — what an `InkWell` gave and a bare
///   `GestureDetector` never did.
/// - Screen readers get the tap and long-press actions, exactly as from a
///   `GestureDetector`. Wrap it in `Semantics` for a label.
/// - Null [onTap] and [onLongPress] disable it: no feedback, no actions.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.feedback = PressFeedback.scale,
    this.haptic,
    this.behavior = HitTestBehavior.opaque,
    this.borderRadius,
    this.pressedScale = 0.97,
    this.pressedOpacity = 0.4,
    this.highlightColor,
    this.focusNode,
    this.autofocus = false,
    this.excludeFromSemantics = false,
  });

  final Widget child;
  final VoidCallback? onTap;

  /// Plays a medium haptic as it fires: a long press opens something, and
  /// iOS confirms that through the finger.
  final VoidCallback? onLongPress;

  final PressFeedback feedback;

  /// Played when [onTap] fires — never on touch-down. Leave it null for
  /// ordinary buttons; see `AppHaptics` for when one earns its place.
  final Haptic? haptic;

  /// Opaque by default, so the whole box responds — padding included. That
  /// is what makes a small control's touch area as large as its layout.
  final HitTestBehavior behavior;

  /// Shapes the [PressFeedback.highlight] tint and the focus ring.
  final BorderRadiusGeometry? borderRadius;

  /// For [PressFeedback.scale]. `0.97` is right for buttons; large cards can
  /// take a little more.
  final double pressedScale;

  /// For [PressFeedback.dim].
  final double pressedOpacity;

  /// For [PressFeedback.highlight]. Defaults to the ink colour at 8%, which
  /// works on both palettes.
  final Color? highlightColor;

  final FocusNode? focusNode;
  final bool autofocus;
  final bool excludeFromSemantics;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  /// 0 at rest, 1 fully pressed. Unbounded, because a spring may carry it
  /// fractionally past either end on its way.
  late final AnimationController _press =
      AnimationController.unbounded(vsync: this);

  bool _focused = false;
  bool _focusVisible = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addHighlightModeListener(_handleHighlightMode);
  }

  @override
  void didUpdateWidget(Pressable old) {
    super.didUpdateWidget(old);
    // Disabled mid-press — say, the action it triggered is now in flight.
    if (!_enabled && _press.value != 0) {
      _press.stop();
      _press.value = 0;
    }
    _updateFocusRing();
  }

  @override
  void dispose() {
    FocusManager.instance.removeHighlightModeListener(_handleHighlightMode);
    _claims.removeWhere((_, owner) => owner == this);
    _press.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool focused) {
    _focused = focused;
    _updateFocusRing();
  }

  void _handleHighlightMode(FocusHighlightMode _) => _updateFocusRing();

  /// The ring is for keyboard and switch users: it shows only while focus is
  /// being driven by keys, never because a finger happened to focus it.
  void _updateFocusRing() {
    final visible = _focused &&
        _enabled &&
        FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    if (visible != _focusVisible && mounted) {
      setState(() => _focusVisible = visible);
    }
  }

  /// Touches already claimed by a Pressable deeper in the tree.
  ///
  /// Pointer-down reaches the innermost listener first, so the first
  /// Pressable to see a pointer is the one under the finger. Any Pressable
  /// around it sees the same pointer afterwards and stays still: on iOS only
  /// the control you touch highlights, not the row it sits in. The inner one
  /// also wins the tap, as the innermost recognizer always does.
  static final Map<int, _PressableState> _claims = <int, _PressableState>{};

  /// True while the current touch belongs to a Pressable inside this one.
  bool _yielded = false;

  void _handlePointerDown(PointerDownEvent event) {
    final owner = _claims[event.pointer];
    if (owner != null && owner != this && owner.mounted) {
      _yielded = true;
      return;
    }
    _yielded = false;
    if (widget.onTap != null) _claims[event.pointer] = this;
  }

  void _handlePointerEnd(PointerEvent event) {
    if (_claims[event.pointer] == this) _claims.remove(event.pointer);
    _yielded = false;
    _pressOut();
  }

  void _pressIn() {
    if (!_enabled || _yielded) return;
    _press.stop();
    _press.value = 1;
  }

  void _pressOut() {
    if (_press.value == 0 && !_press.isAnimating) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _press.stop();
      _press.value = 0;
      return;
    }
    _press.animateWith(
      SpringSimulation(AppSprings.release, _press.value, 0, _press.velocity),
    );
  }

  void _handleTap() {
    final haptic = widget.haptic;
    if (haptic != null) AppHaptics.play(haptic);
    widget.onTap?.call();
  }

  void _handleLongPress() {
    AppHaptics.medium();
    widget.onLongPress?.call();
  }

  /// Enter or Space while focused: the same flash a finger would get.
  void _activate() {
    _pressIn();
    _pressOut();
    _handleTap();
  }

  Widget _withFeedback(Widget child) {
    switch (widget.feedback) {
      case PressFeedback.scale:
        return ScaleTransition(
          scale: _press.drive(Tween(begin: 1.0, end: widget.pressedScale)),
          child: child,
        );
      case PressFeedback.dim:
        return FadeTransition(
          opacity: _press.drive(Tween(begin: 1.0, end: widget.pressedOpacity)),
          child: child,
        );
      case PressFeedback.highlight:
        final tint =
            widget.highlightColor ?? AppColors.textDark.withValues(alpha: 0.08);
        return AnimatedBuilder(
          animation: _press,
          child: child,
          builder: (context, child) => DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              color: tint.withValues(
                alpha: tint.a * _press.value.clamp(0.0, 1.0),
              ),
              borderRadius: widget.borderRadius,
            ),
            child: child,
          ),
        );
      case PressFeedback.none:
        return child;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _withFeedback(widget.child);

    if (_focusVisible) {
      child = DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary, width: 2),
          borderRadius: widget.borderRadius,
        ),
        child: child,
      );
    }

    final enabled = _enabled;
    final canTap = widget.onTap != null;
    final canLongPress = widget.onLongPress != null;

    child = GestureDetector(
      behavior: widget.behavior,
      excludeFromSemantics: widget.excludeFromSemantics,
      // Only a target that does something on tap shows the tap: a bubble that
      // only long-presses must not flash for a tap that will do nothing.
      onTapDown: canTap ? (_) => _pressIn() : null,
      onTapUp: canTap ? (_) => _pressOut() : null,
      onTapCancel: canTap ? _pressOut : null,
      onTap: canTap ? _handleTap : null,
      // A long press rejects the tap first, which releases the press; the
      // start puts it straight back, so it stays down until the finger lifts.
      onLongPressStart: canLongPress ? (_) => _pressIn() : null,
      onLongPress: canLongPress ? _handleLongPress : null,
      onLongPressEnd: canLongPress ? (_) => _pressOut() : null,
      child: child,
    );

    // Claims the touch for the innermost Pressable (see [_claims]), and is a
    // safety net under the gestures: however the touch ends — lifted,
    // cancelled by the system, or after a long press the recognizer no longer
    // reports — the pressed state never outlives the finger.
    child = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerEnd,
      onPointerCancel: _handlePointerEnd,
      child: child,
    );

    // Focus, activation and the cursor are assembled by hand rather than with
    // FocusableActionDetector. Its MouseRegion is opaque, and an opaque region
    // claims every touch inside its box — which would quietly turn [behavior]
    // into opaque, so a translucent Pressable laid over a PageView or a map
    // would block the swipe beneath it.
    return Actions(
      actions: canTap
          ? <Type, Action<Intent>>{
              ActivateIntent: CallbackAction<ActivateIntent>(
                onInvoke: (_) {
                  _activate();
                  return null;
                },
              ),
            }
          : const <Type, Action<Intent>>{},
      child: Focus(
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        canRequestFocus: enabled,
        skipTraversal: !enabled,
        onFocusChange: _handleFocusChange,
        child: MouseRegion(
          opaque: false,
          cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
          child: child,
        ),
      ),
    );
  }
}
