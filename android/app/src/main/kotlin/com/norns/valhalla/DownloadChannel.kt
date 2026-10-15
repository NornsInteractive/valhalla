package com.norns.valhalla

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.webkit.MimeTypeMap
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.io.File
import java.lang.ref.WeakReference
import java.util.Locale

object DownloadChannel {

    private const val CHANNEL = "valhalla/downloads"
    private const val NOTIFICATION_CHANNEL_ID = "valhalla_downloads_progress"
    private const val NOTIFICATION_PERMISSION_REQUEST = 4202

    private var hasRequestedNotificationPermission = false
    private var methodChannel: MethodChannel? = null
    @Volatile
    private var queueMessenger: BinaryMessenger? = null
    private var notificationQueue: BinaryMessenger.TaskQueue? = null
    @Volatile
    private var activityRef: WeakReference<Activity>? = null

    fun register(activity: Activity, flutterEngine: FlutterEngine) {
        activityRef = WeakReference(activity)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        val context = activity.applicationContext
        if (queueMessenger !== messenger) {
            notificationQueue = messenger.makeBackgroundTaskQueue()
            queueMessenger = messenger
        }
        val channel = MethodChannel(
            messenger,
            CHANNEL,
            StandardMethodCodec.INSTANCE,
            // AudioService keeps its engine alive across Activity recreation; keep the same FIFO too.
            checkNotNull(notificationQueue),
        )
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "reportProgress" -> handleReportProgress(context, messenger, call, result)
                "openFile" -> {
                    val currentActivity = activityRef?.get()
                    if (currentActivity == null) {
                        result.error("OPEN_FAILED", null, null)
                    } else {
                        currentActivity.runOnUiThread {
                            try {
                                if (queueMessenger === messenger && isCurrentActivity(currentActivity)) {
                                    handleOpenFile(currentActivity, call, result)
                                } else {
                                    result.error("OPEN_FAILED", null, null)
                                }
                            } catch (_: Exception) {
                                result.error("OPEN_FAILED", null, null)
                            }
                        }
                    }
                }
                "getNasLaunchAction" -> {
                    val currentActivity = activityRef?.get()
                    if (currentActivity == null) {
                        result.success(false)
                    } else {
                        currentActivity.runOnUiThread {
                            val shouldOpen = if (queueMessenger === messenger && isCurrentActivity(currentActivity)) {
                                (currentActivity as? MainActivity)?.consumePendingOpenNasDownloads() ?: false
                            } else {
                                false
                            }
                            result.success(shouldOpen)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun isCurrentActivity(activity: Activity): Boolean =
        activityRef?.get() === activity && !activity.isFinishing && !activity.isDestroyed

    fun notifyOpenNasDownloads(onSuccess: (() -> Unit)? = null) {
        val act = activityRef?.get()
        val deliver = {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod(
                    "openNasDownloads",
                    null,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            onSuccess?.invoke()
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                        override fun notImplemented() {}
                    },
                )
            }
        }
        if (act != null) {
            act.runOnUiThread(deliver)
        } else {
            deliver()
        }
    }

    fun notifyOpenTransfers(onSuccess: (() -> Unit)? = null) {
        val act = activityRef?.get()
        val deliver = {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod(
                    "openTransfers",
                    null,
                    object : MethodChannel.Result {
                        override fun success(result: Any?) {
                            onSuccess?.invoke()
                        }
                        override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {}
                        override fun notImplemented() {}
                    },
                )
            }
        }
        if (act != null) {
            act.runOnUiThread(deliver)
        } else {
            deliver()
        }
    }

    private fun createOpenTransfersIntent(context: Context, requestCode: Int, target: String?): PendingIntent {
        return PendingIntent.getActivity(
            context,
            requestCode,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                when (target) {
                    "nas" -> putExtra(MainActivity.EXTRA_OPEN_NAS_DOWNLOADS, true)
                    "update" -> { /* No launch action extra for update */ }
                    else -> putExtra(TransferNotifier.EXTRA_OPEN_TRANSFERS, true)
                }
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun handleReportProgress(
        context: Context,
        messenger: BinaryMessenger,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val id = call.argument<String>("id")
        val name = call.argument<String>("name") ?: "download"
        val bytes = (call.argument<Number>("bytes"))?.toLong() ?: 0L
        val total = (call.argument<Number>("total"))?.toLong() ?: 0L
        val status = call.argument<String>("status") ?: "running"

        if (id == null) {
            result.error("INVALID_ARGUMENT", "id is required", null)
            return
        }

        if (queueMessenger !== messenger) {
            result.success(false)
            return
        }

        // Check notification permissions (Android 13+)
        if (!checkAndRequestNotificationPermission(context, messenger)) {
            result.success(false)
            return
        }

        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        if (manager == null) {
            result.success(false)
            return
        }

        if (!ensureChannel(context, manager)) {
            result.success(false)
            return
        }

        val notificationId = 20000 + ((id.hashCode() and 0x7FFFFFFF) % 50000)

        if (status == "canceled") {
            if (queueMessenger !== messenger) {
                result.success(false)
                return
            }
            manager.cancel(notificationId)
            result.success(true)
            return
        }

        val openTransfersPendingIntent = createOpenTransfersIntent(
            context, notificationId, call.argument<String>("target"),
        )

        val builder = NotificationCompat.Builder(context, NOTIFICATION_CHANNEL_ID)
            .setContentTitle(name)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setContentIntent(openTransfersPendingIntent)

        when (status) {
            "completed" -> {
                builder.setSmallIcon(android.R.drawable.stat_sys_download_done)
                    .setContentText(context.getString(R.string.transfer_complete_body))
                    .setOngoing(false)
                    .setAutoCancel(true)
                    .setProgress(0, 0, false)
                    .setPriority(NotificationCompat.PRIORITY_DEFAULT)

                // Open through Dart's integrity gate, never a stale file-provider URI.
            }

            "running" -> {
                val isIndeterminate = total <= 0L
                val maxProgress = if (isIndeterminate) 0 else 100
                val progress = if (isIndeterminate) {
                    0
                } else {
                    ((bytes * 100) / total).toInt().coerceIn(0, 100)
                }

                val progressText = if (total > 0L) {
                    "${formatBytes(bytes)} / ${formatBytes(total)} ($progress%)"
                } else {
                    formatBytes(bytes)
                }

                builder.setOngoing(true)
                    .setAutoCancel(false)
                    .setProgress(maxProgress, progress, isIndeterminate)
                    .setContentText(progressText)
            }

            "paused" -> {
                builder.setOngoing(false)
                    .setAutoCancel(false)
                    .setContentText(context.getString(R.string.download_status_paused))
            }

            "failed" -> {
                builder.setOngoing(false)
                    .setAutoCancel(true)
                    .setProgress(0, 0, false)
                    .setContentText(context.getString(R.string.download_status_failed))
            }

            "queued" -> {
                builder.setOngoing(false)
                    .setAutoCancel(false)
                    .setProgress(0, 0, false)
                    .setContentText(context.getString(R.string.download_status_queued))
            }

            else -> {
                builder.setOngoing(false)
                    .setAutoCancel(true)
                    .setContentText(status)
            }
        }

        try {
            if (queueMessenger !== messenger) {
                result.success(false)
                return
            }
            manager.notify(notificationId, builder.build())
            result.success(true)
        } catch (_: SecurityException) {
            result.success(false)
        }
    }

    private fun handleOpenFile(
        activity: Activity,
        call: MethodCall,
        result: MethodChannel.Result,
    ) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGUMENT", "path is required", null)
            return
        }

        val file = File(path)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "File does not exist: $path", null)
            return
        }

        try {
            val uri = FileProvider.getUriForFile(
                activity,
                "${activity.packageName}.fileprovider",
                file,
            )
            val mimeType = getMimeType(file.name)
            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeType)
                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK
            }
            val chooser = Intent.createChooser(viewIntent, file.name).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            activity.startActivity(chooser)
            result.success(null)
        } catch (e: ActivityNotFoundException) {
            result.error("NO_APP_FOUND", "No application found to open file", e.message)
        } catch (e: Exception) {
            result.error("OPEN_FAILED", e.message, null)
        }
    }

    private fun checkAndRequestNotificationPermission(context: Context, messenger: BinaryMessenger): Boolean {
        if (Build.VERSION.SDK_INT >= 33) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                val activity = activityRef?.get()
                if (activity != null) {
                    activity.runOnUiThread {
                        if (queueMessenger === messenger && isCurrentActivity(activity) && !hasRequestedNotificationPermission) {
                            hasRequestedNotificationPermission = true
                            try {
                                ActivityCompat.requestPermissions(
                                    activity,
                                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                    NOTIFICATION_PERMISSION_REQUEST,
                                )
                            } catch (_: Exception) {
                                // The report already returned false; a detached permission UI must not crash.
                            }
                        }
                    }
                }
                return false
            }
        }
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun ensureChannel(context: Context, manager: NotificationManager): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return true
        val existing = manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID)
        if (existing != null) {
            return existing.importance != NotificationManager.IMPORTANCE_NONE
        }

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            context.getString(R.string.download_channel_name),
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = context.getString(R.string.download_channel_description)
        }
        manager.createNotificationChannel(channel)
        return true
    }

    private fun getMimeType(fileName: String): String {
        val extension = MimeTypeMap.getFileExtensionFromUrl(fileName).ifEmpty {
            fileName.substringAfterLast('.', "")
        }.lowercase()
        return if (extension.isNotEmpty()) {
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension) ?: "*/*"
        } else {
            "*/*"
        }
    }

    private fun formatBytes(bytes: Long): String {
        if (bytes < 1024) return "$bytes B"
        val kb = bytes / 1024.0
        if (kb < 1024) return String.format(Locale.US, "%.1f KB", kb)
        val mb = kb / 1024.0
        if (mb < 1024) return String.format(Locale.US, "%.1f MB", mb)
        val gb = mb / 1024.0
        return String.format(Locale.US, "%.1f GB", gb)
    }
}
