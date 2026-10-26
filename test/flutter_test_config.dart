import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Runs once before every test file — the Flutter test runner picks this file
/// up by name.
///
/// The app wraps everything in `ScreenUtilInit`; widget tests pump screens on
/// their own, so ScreenUtil's late fields were never set and any widget using
/// `.h` / `.w` / `spacerH` threw `LateInitializationError` before it could be
/// laid out — which took every layout test in the suite down with it.
///
/// The "device" configured here is the app's own design size, so every
/// ScreenUtil unit resolves at a scale of exactly 1 and the layout tests keep
/// measuring the layout rather than a scale factor.
///
/// The environment is loaded empty for the same reason: `Env` reads `dotenv`,
/// which throws until something has loaded it, and the keys with defaults (the
/// map tiles) are exactly what tests should exercise. A test that needs a
/// value loads its own over the top.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  ScreenUtil.configure(
    data: const MediaQueryData(size: Size(390, 844)),
    designSize: const Size(390, 844),
    splitScreenMode: false,
    minTextAdapt: false,
  );
  dotenv.loadFromString(isOptional: true);
  await testMain();
}
