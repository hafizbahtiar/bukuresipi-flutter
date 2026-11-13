package com.bukuresipi

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.credentials.CreateCredentialResponse
import androidx.credentials.CreatePublicKeyCredentialRequest
import androidx.credentials.CreatePublicKeyCredentialResponse
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.GetPublicKeyCredentialOption
import androidx.credentials.PublicKeyCredential
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import androidx.credentials.exceptions.domerrors.InvalidStateError
import androidx.credentials.exceptions.publickeycredential.CreatePublicKeyCredentialDomException
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "bukuresipi/passkey").setMethodCallHandler { call, result ->
            val json = call.arguments as? String
            when {
                // Passkeys need Android 9; older phones never see the buttons.
                call.method == "available" -> result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
                call.method == "create" && json != null -> createPasskey(json, result)
                call.method == "get" && json != null -> getPasskey(json, result)
                else -> result.notImplemented()
            }
        }
    }

    // Passkeys (lib/features/auth/data/passkey_auth.dart). Credential Manager takes the API's WebAuthn options as JSON
    // and answers with the JSON the API verifies, so nothing is parsed here. null = the user closed the sheet.
    private fun createPasskey(json: String, result: MethodChannel.Result) {
        CredentialManager.create(this).createCredentialAsync(
            this, CreatePublicKeyCredentialRequest(json), null, ContextCompat.getMainExecutor(this),
            object : CredentialManagerCallback<CreateCredentialResponse, CreateCredentialException> {
                override fun onResult(r: CreateCredentialResponse) =
                    result.success((r as? CreatePublicKeyCredentialResponse)?.registrationResponseJson)

                override fun onError(e: CreateCredentialException) = when {
                    e is CreateCredentialCancellationException -> result.success(null)
                    // The API's excludeCredentials named a passkey this phone already holds.
                    e is CreatePublicKeyCredentialDomException && e.domError is InvalidStateError -> result.error("passkey_exists", e.type, null)
                    else -> result.error("passkey_failed", e.type, null)
                }
            },
        )
    }

    private fun getPasskey(json: String, result: MethodChannel.Result) {
        CredentialManager.create(this).getCredentialAsync(
            this, GetCredentialRequest(listOf(GetPublicKeyCredentialOption(json))), null, ContextCompat.getMainExecutor(this),
            object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                override fun onResult(r: GetCredentialResponse) =
                    result.success((r.credential as? PublicKeyCredential)?.authenticationResponseJson)

                override fun onError(e: GetCredentialException) = when (e) {
                    is GetCredentialCancellationException -> result.success(null)
                    is NoCredentialException -> result.error("no_passkey", e.type, null)
                    else -> result.error("passkey_failed", e.type, null)
                }
            },
        )
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Reopened from Recents (or recreated after Android closed the app), the activity gets the share intent it
        // first started with: receive_sharing_intent would hand the old share over again and the share screen would
        // open for a post sent long ago. Swap it for a plain launch before super (the plugin reads it on attach).
        val replayed = savedInstanceState != null || intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0
        if (replayed && intent.action in SHARE_ACTIONS) intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
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

    private companion object {
        val SHARE_ACTIONS = setOf(Intent.ACTION_SEND, Intent.ACTION_SEND_MULTIPLE)
    }
}
