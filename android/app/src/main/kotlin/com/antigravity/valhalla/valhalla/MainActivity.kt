package com.antigravity.valhalla.valhalla

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {

    companion object {
        private const val CHANNEL = "valhalla/keepalive"
        private const val NOTIFICATION_PERMISSION_REQUEST = 4202
    }

    /**
     * Set when the activity was opened by tapping a "transfer finished"
     * notification, and cleared once Dart has read it.
     *
     * Deliberately *not* derived from [getIntent] on every call: the launch
     * intent keeps reporting the original extra for the whole process
     * lifetime, so a warm resume would re-open the transfer list every time
     * the user came back from the app switcher.
     */
    private var pendingOpenTransfers = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        DownloadChannel.register(this, flutterEngine)
        UpdateChannel.register(this, flutterEngine)
        NasNetworkChannel.register(this, flutterEngine)
        DiagnosticsChannel.register(this, flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "valhalla/model_authorization")
            .setMethodCallHandler { call, result ->
                if (call.method != "openBrowser") {
                    result.notImplemented()
                } else {
                    try {
                        val url = Uri.parse(call.argument<String>("url") ?: "")
                        if (url.scheme != "https" || url.host != "auth.openai.com" ||
                            !url.userInfo.isNullOrEmpty() || (url.port != -1 && url.port != 443)) {
                            result.error("AGENT_MODEL_ENDPOINT_INVALID", null, null)
                        } else {
                            startActivity(Intent(Intent.ACTION_VIEW, url).addCategory(Intent.CATEGORY_BROWSABLE))
                            result.success(true)
                        }
                    } catch (_: Exception) {
                        // Never include authorization URLs or codes in errors.
                        result.error("AGENT_MODEL_BROWSER_FAILED", null, null)
                    }
                }
            }

        consumeLaunchExtras(intent)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sessionCount = call.argument<Int>("sessionCount") ?: 1
                        try {
                            ensureNotificationPermission()
                            SshKeepAliveService.start(applicationContext, sessionCount)
                            result.success(true)
                        } catch (error: Exception) {
                            // A background start can be refused by the system.
                            // Report it instead of crashing so the Dart side can
                            // fall back to running without background protection.
                            result.error(
                                "foreground_service_start_failed",
                                error.message,
                                null,
                            )
                        }
                    }

                    "stop" -> {
                        SshKeepAliveService.stop(applicationContext)
                        result.success(true)
                    }

                    "updateSessionCount" -> {
                        val sessionCount = call.argument<Int>("sessionCount") ?: 0
                        SshKeepAliveService.updateSessionCount(
                            applicationContext,
                            sessionCount,
                        )
                        result.success(true)
                    }

                    "isRunning" -> result.success(SshKeepAliveService.isRunning)

                    "getLaunchAction" -> {
                        // Read-and-clear: the caller gets a one-shot signal, so a
                        // later rebuild of the shell does not replay the action.
                        val openTransfers = pendingOpenTransfers
                        pendingOpenTransfers = false
                        result.success(if (openTransfers) "openTransfers" else null)
                    }

                    "notifyTransferCompleted" -> {
                        val count = call.argument<Int>("count") ?: 1
                        try {
                            ensureNotificationPermission()
                            TransferNotifier.notifyCompleted(applicationContext, count)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("transfer_notify_failed", error.message, null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Warm-start path: the notification's PendingIntent carries
     * SINGLE_TOP|CLEAR_TOP, so tapping it while the activity is alive lands
     * here rather than in [onCreate].
     */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // setIntent keeps getIntent() consistent for anything else that reads
        // it; the flag below is what Dart actually consumes.
        setIntent(intent)
        consumeLaunchExtras(intent)
    }

    private fun consumeLaunchExtras(intent: Intent?) {
        if (intent?.getBooleanExtra(TransferNotifier.EXTRA_OPEN_TRANSFERS, false) == true) {
            pendingOpenTransfers = true
        }
    }

    private fun ensureNotificationPermission() {
        if (Build.VERSION.SDK_INT < 33) return
        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST,
        )
    }
}
