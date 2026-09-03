import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

abstract final class ScreenGuard {
  static const MethodChannel _channel = MethodChannel('radius/screen_guard');

  static bool get _supported =>
      !kIsWeb &&
          !kDebugMode &&
          defaultTargetPlatform == TargetPlatform.android;

  static int _claims = 0;

  @visibleForTesting
  static bool get isActive => _claims > 0;

  @visibleForTesting
  static void resetForTest() => _claims = 0;

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
    } on MissingPluginException catch (_) {
    }
  }
}

mixin ScreenGuardMixin<T extends StatefulWidget> on State<T> {
  VoidCallback? _release;

  @override
  void initState() {
    super.initState();
    ScreenGuard.claim().then((release) {
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