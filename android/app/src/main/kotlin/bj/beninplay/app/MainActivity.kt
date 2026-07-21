package bj.beninplay.app

import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity est requis par le plugin local_auth (biométrie).
class MainActivity : FlutterFragmentActivity() {
    private val secureChannel = "beninplay/secure"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Bloque captures d'écran + enregistrement (Zone Dark)
                    "enable" -> {
                        runOnUiThread { window.addFlags(WindowManager.LayoutParams.FLAG_SECURE) }
                        result.success(true)
                    }
                    "disable" -> {
                        runOnUiThread { window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE) }
                        result.success(true)
                    }
                    // Empreinte appareil stable (ANDROID_ID) — anti-multi-comptes
                    "deviceId" -> {
                        val id = try {
                            Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        } catch (e: Exception) {
                            null
                        }
                        result.success(id)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
