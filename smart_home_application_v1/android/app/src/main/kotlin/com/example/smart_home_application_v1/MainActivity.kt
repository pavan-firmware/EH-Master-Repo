package com.example.smart_home_application_v1

import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.Intent
import android.location.LocationManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "eh_home/system_ble"
    private val REQUEST_ENABLE_BT = 1001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAndroidSdkVersion" -> {
                    result.success(Build.VERSION.SDK_INT)
                }
                "requestBluetoothEnable" -> {
                    val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                    if (adapter == null) {
                        result.success(false)
                        return@setMethodCallHandler
                    }
                    if (adapter.isEnabled) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    val enableBtIntent = Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE)
                    try {
                        pendingResult = result
                        startActivityForResult(enableBtIntent, REQUEST_ENABLE_BT)
                    } catch (e: Exception) {
                        pendingResult = null
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "isBluetoothEnabled" -> {
                    val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                    val adapter = bluetoothManager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
                    result.success(adapter?.isEnabled == true)
                }
                "isLocationEnabled" -> {
                    val locationManager = getSystemService(Context.LOCATION_SERVICE) as? LocationManager
                    if (locationManager == null) {
                        result.success(true)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        result.success(locationManager.isLocationEnabled)
                    } else {
                        val isGps = locationManager.isProviderEnabled(LocationManager.GPS_PROVIDER)
                        val isNetwork = locationManager.isProviderEnabled(LocationManager.NETWORK_PROVIDER)
                        result.success(isGps || isNetwork)
                    }
                }
                "openBluetoothSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "openLocationSettings" -> {
                    try {
                        val intent = Intent(Settings.ACTION_LOCATION_SOURCE_SETTINGS).apply {
                            flags = Intent.FLAG_ACTIVITY_NEW_TASK
                        }
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_ENABLE_BT) {
            val enabled = (resultCode == Activity.RESULT_OK)
            pendingResult?.success(enabled)
            pendingResult = null
        }
    }
}
