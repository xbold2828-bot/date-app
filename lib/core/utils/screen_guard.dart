import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Blocks screenshots and screen recording while a screen is open.
///
/// Somebody else's photos are theirs. Screenshotting a profile is how those
/// photos end up somewhere the person who posted them never agreed to, and the
/// platform gives us one lever against it.
///
/// ## What this actually guarantees
///
/// **On Android: a real block.** `FLAG_SECURE` makes the system capture a black
/// frame, and it covers screen recording and the recents thumbnail too.
///
/// **On iOS: nothing.** There is no equivalent — an app can be told a
/// screenshot *happened*, after the fact, but not prevent one. Calls here are
/// silently no-ops there rather than pretending otherwise.
///
/// And on any platform, a second phone pointed at the screen defeats it
/// entirely. This raises the effort; it does not make photos safe. Nothing that
/// reaches a screen can be made un-copyable, so this belongs in the same
/// category as the blur on a locked card: a deterrent, never a boundary to
/// trust.
///
/// ## Why it is reference-counted
///
/// The flag is set on the whole window, not on a widget, so two overlapping
/// screens that both want it cannot each own it: the first to close would clear
/// the flag out from under the second. Callers take and release a claim, and
/// the flag only drops when the last one is gone.
class ScreenGuard {
  const ScreenGuard._();

  static const MethodChannel _channel = MethodChannel('radius/screen_guard');

  /// Only Android implements the channel. Checked before every call so a
  /// desktop or web build never pays for a platform message that cannot land.
  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static int _claims = 0;

  /// Whether anything currently holds the guard. Exposed for tests.
  @visibleForTesting
  static bool get isActive => _claims > 0;

  @visibleForTesting
  static void resetForTest() => _claims = 0;

  /// Take a claim. Returns a releaser — call it exactly once, from `dispose`.
  ///
  /// Never throws: a platform channel that is missing, or an OEM that refuses
  /// the flag, must not take a profile screen down with it.
  static Future<VoidCallback> claim() async {
    _claims++;
    if (_claims == 1) await _set('enable');

    var released = false;
    return () {
      if (released) return;
      released = true;
      _claims--;
      if (_claims == 0) _set('disable');
    };
  }

  static Future<void> _set(String method) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<bool>(method);
    } on PlatformException catch (_) {
      // Nothing to do and nothing to say: the screen still works, it is simply
      // capturable. Failing loudly here would be worse than the miss.
    } on MissingPluginException catch (_) {
      // Running against a host that has not been rebuilt with the channel.
    }
  }
}

/// Holds a [ScreenGuard] claim for as long as the widget is mounted.
///
/// Mix into a `State` and the claim is taken on `initState` and released on
/// `dispose` — including the dispose that happens when a sheet is dragged away
/// rather than closed by its own button, which is the path a screen that
/// managed the flag by hand would forget.
mixin ScreenGuardMixin<T extends StatefulWidget> on State<T> {
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    ScreenGuard.claim().then((release) {
      // Disposed before the platform answered: release immediately rather than
      // leaving the window locked for the rest of the session.
      if (!mounted) {
        release();
        return;
      }
      _release = release;
    });
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }
}
