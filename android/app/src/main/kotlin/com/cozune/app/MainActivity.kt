package com.cozune.app

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Host activity, plus the one thing Flutter cannot do on its own: block
 * screenshots and screen recording of the window.
 *
 * `FLAG_SECURE` is a window flag, so it is all-or-nothing for the whole app and
 * has to be toggled around the screens that need it — see `ScreenGuard` on the
 * Dart side. Done natively through a channel rather than with a plugin: it is
 * four lines of platform code, and the packages that wrap it are a dependency
 * to audit and update for no gain.
 */
class MainActivity : FlutterActivity() {
    private companion object {
        const val CHANNEL = "radius/screen_guard"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        // Window flags must be set on the UI thread; the
                        // channel handler already runs there.
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                        result.success(true)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
