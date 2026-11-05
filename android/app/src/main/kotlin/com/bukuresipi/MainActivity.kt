package com.bukuresipi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // For "Signed-in devices" (lib/features/auth/data/auth_api.dart). Android has no field for the shop name
    // ("Infinix HOT 40 Pro"); the phone's own name in Settings > About phone is usually it, unless the user renamed it.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bukuresipi/device").setMethodCallHandler { call, result ->
            if (call.method != "info") return@setMethodCallHandler result.notImplemented()
            val model = "${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL}"
            val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1)
                Settings.Global.getString(contentResolver, Settings.Global.DEVICE_NAME) else null
            result.success(mapOf("name" to (name?.takeIf { it.isNotBlank() } ?: model), "model" to model, "os" to "Android ${Build.VERSION.RELEASE}"))
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
