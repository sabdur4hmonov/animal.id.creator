package ai.biolivestock.biolivestock_capture

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import java.io.File
import android.content.Intent
import com.google.ar.core.ArCoreApk
import com.google.ar.core.Session
import com.google.ar.core.Config
import org.json.JSONObject
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val matchingWorker=Executors.newSingleThreadExecutor()
    private var arResult: MethodChannel.Result? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.biolivestock/app_mode")
            .setMethodCallHandler { call, result ->
                if (call.method == "isDemo") result.success(packageName.split('.').contains("demo"))
                else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"ai.biolivestock/advisory_matching")
            .setMethodCallHandler { call,result ->
                if(call.method!="compare")result.notImplemented()
                else matchingWorker.execute {
                    try {
                        val request=JSONObject(call.arguments as String)
                        val output=AdvisoryOrb(applicationContext,request.getJSONObject("rules"),request.getString("rules_sha256")).compare(request)
                        runOnUiThread { result.success(output.toString()) }
                    }catch(e:Throwable){runOnUiThread{result.error("matching_unavailable",e.javaClass.simpleName,null)}}
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ai.biolivestock/ar_measurement")
            .setMethodCallHandler { call, result ->
                when(call.method) {
                    "probe" -> {
                        val availability=ArCoreApk.getInstance().checkAvailability(this)
                        var depth: Boolean?=null
                        if(availability==ArCoreApk.Availability.SUPPORTED_INSTALLED) {
                            try { val candidate=Session(this);try { depth=candidate.isDepthModeSupported(Config.DepthMode.AUTOMATIC) } finally { candidate.close() } } catch(_: Exception) { }
                        }
                        val services=try { packageManager.getPackageInfo("com.google.ar.core",0).versionName } catch(_: Exception){null}
                        result.success(mapOf("model" to Build.MODEL,"android" to Build.VERSION.RELEASE,
                            "availability" to availability.name,"depth" to depth,"ar_services" to services))
                    }
                    "measure" -> {
                        if(arResult!=null) result.error("busy","AR already running",null)
                        else {
                            arResult=result
                            try { startActivityForResult(Intent(this,ArMeasureActivity::class.java)
                                .putExtra("spec",call.arguments as String),6412) }
                            catch(e: Exception){arResult=null;result.error("session_unavailable",e.javaClass.simpleName,null)}
                        }
                    }
                    else -> result.notImplemented()
                }
            }
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

    override fun onDestroy(){matchingWorker.shutdown();super.onDestroy()}

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode,resultCode,data)
        if(requestCode==6412) {
            val result=arResult;arResult=null
            val path=data?.getStringExtra("measurement_file")
            if(path!=null) {
                try {
                    val file=File(path).canonicalFile
                    check(file.parentFile==cacheDir.canonicalFile && file.name.startsWith("ar-result-") && file.length()<=20000000)
                    val payload=file.readText()
                    if(resultCode==RESULT_OK)result?.success(payload)
                    else result?.error(data?.getStringExtra("error")?:"interrupted","AR attempt not completed",payload)
                    file.delete()
                }catch(e:Exception){result?.error("invalid_result",e.javaClass.simpleName,null)}
            } else result?.error(data?.getStringExtra("error")?:"interrupted","AR attempt not completed",data?.getStringExtra("partial"))
        }
    }
}
