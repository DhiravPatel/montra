package app.montra.mobile

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lets Dart mark screens that show secrets (two-step verification
        // setup key, recovery codes) as secure: no screenshots, no screen
        // recording, blank thumbnail in Recents. See lib/core/widgets/secure_window.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SECURE_WINDOW_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val SECURE_WINDOW_CHANNEL = "app.montra.mobile/secure_window"
    }
}
