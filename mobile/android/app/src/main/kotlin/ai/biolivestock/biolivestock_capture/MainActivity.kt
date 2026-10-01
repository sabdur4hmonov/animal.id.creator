package ai.biolivestock.biolivestock_capture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.biolivestock/device_signals")
            .setMethodCallHandler { call, result ->
                if (call.method != "readSignals") {
                    result.notImplemented()
                } else {
                    // These local heuristics can be hidden/forged; no attestation claim.
                    val model = Build.MODEL.lowercase()
                    val fingerprint = Build.FINGERPRINT.lowercase()
                    val emulator = fingerprint.startsWith("generic") ||
                        fingerprint.contains("emulator") || model.contains("emulator") ||
                        model.contains("sdk_gphone") || model.contains("google_sdk") ||
                        (Build.BRAND.startsWith("generic") && Build.DEVICE.startsWith("generic")) ||
                        Build.PRODUCT.contains("sdk")
                    val rooted = Build.TAGS?.contains("test-keys") == true ||
                        listOf("/system/bin/su", "/system/xbin/su", "/sbin/su", "/data/adb/magisk")
                            .any { File(it).exists() }
                    result.success(mapOf("source" to "android_heuristic",
                        "is_rooted" to rooted, "is_emulator" to emulator))
                }
            }
    }
}
