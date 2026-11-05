package com.bukuresipi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // "Infinix X6731" for "Signed-in devices" (lib/features/auth/data/auth_api.dart).
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bukuresipi/device").setMethodCallHandler { call, result ->
            if (call.method == "name") result.success("${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}") else result.notImplemented()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The API sends share pushes on channel "share_ready" (bukuresipi-hono src/lib/push.ts). High importance = a
        // heads-up banner; the user can still lower or mute it in system settings. Android never raises an existing
        // channel, so the first one ("shares", default importance: shade only) is removed rather than changed.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.deleteNotificationChannel("shares")
            val channel = NotificationChannel("share_ready", getString(R.string.channel_shares), NotificationManager.IMPORTANCE_HIGH)
            manager.createNotificationChannel(channel)
        }
    }
}
