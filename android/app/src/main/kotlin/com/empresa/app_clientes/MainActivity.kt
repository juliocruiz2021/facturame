package com.empresa.app_clientes

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.telephony.SubscriptionManager
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
                        result.success(leerNumeroCelular())
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
        if (!tienePermiso()) return null
        return try {
            // Intento 1: TelephonyManager.line1Number (funciona en algunos operadores)
            val tm = getSystemService(TELEPHONY_SERVICE) as TelephonyManager
            val num1 = tm.line1Number
            if (!num1.isNullOrBlank()) return num1

            // Intento 2: SubscriptionManager (funciona mejor en Android 5.1+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                val sm = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager
                val subs = sm.activeSubscriptionInfoList
                if (subs != null) {
                    for (info in subs) {
                        val num2 = info.number
                        if (!num2.isNullOrBlank()) return num2
                    }
                }
            }
            null
        } catch (e: Exception) {
            null
        }
    }
}
