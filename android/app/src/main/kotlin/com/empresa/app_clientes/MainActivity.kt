package com.empresa.app_clientes

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.TelephonyManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "facturame/device_info"
    private val PERM_REQUEST = 101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPhoneNumber" -> {
                        val numero = leerNumeroCelular()
                        result.success(numero)
                    }
                    "requestPhonePermission" -> {
                        val granted = tienePermiso()
                        if (!granted) {
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(
                                    Manifest.permission.READ_PHONE_STATE,
                                    Manifest.permission.READ_PHONE_NUMBERS
                                ),
                                PERM_REQUEST
                            )
                        }
                        result.success(granted)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun tienePermiso(): Boolean {
        val p1 = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
        val p2 = ContextCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS)
        return p1 == PackageManager.PERMISSION_GRANTED && p2 == PackageManager.PERMISSION_GRANTED
    }

    private fun leerNumeroCelular(): String? {
        return try {
            if (!tienePermiso()) return null
            val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
            val numero = tm.line1Number
            if (numero.isNullOrBlank()) null else numero
        } catch (e: Exception) {
            null
        }
    }
}
