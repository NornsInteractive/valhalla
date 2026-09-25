package com.antigravity.valhalla.valhalla

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Keeps the app process alive so long-lived SSH/ACP connections are not
 * reclaimed while the app is in the background.
 *
 * Deliberately does **not** own any connection state: the SSH clients live in
 * Dart. This service only raises the process priority. Owning connections in two
 * places would mean two conflicting sources of truth about whether a server is
 * connected.
 */
class SshKeepAliveService : Service() {

    companion object {
        private const val CHANNEL_ID = "valhalla_keep_alive"
        private const val NOTIFICATION_ID = 4201

        /**
         * True while [onStartCommand] has been reached at least once.
         * Exposed for the Dart side's `isRunning` probe.
         */
        @Volatile
        var isRunning: Boolean = false
            private set

        /** Last reported active-session count, used to update the notification. */
        @Volatile
        private var sessionCount: Int = 0

        fun start(context: Context, sessionCount: Int) {
            val intent = Intent(context, SshKeepAliveService::class.java)
            this.sessionCount = sessionCount
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, SshKeepAliveService::class.java))
        }

        fun updateSessionCount(context: Context, count: Int) {
            sessionCount = count
            if (!isRunning) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(context, count))
        }

        private fun buildNotification(context: Context, sessionCount: Int): Notification {
            ensureChannel(context)

            val openApp = PendingIntent.getActivity(
                context,
                0,
                Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )

            val body = context.resources.getQuantityString(
                R.plurals.keep_alive_body,
                sessionCount,
                sessionCount,
            )

            return NotificationCompat.Builder(context, CHANNEL_ID)
                .setContentTitle(context.getString(R.string.keep_alive_title))
                .setContentText(body)
                .setSmallIcon(android.R.drawable.stat_sys_upload)
                .setContentIntent(openApp)
                .setOngoing(true)
                .setShowWhen(false)
                .setPriority(NotificationCompat.PRIORITY_LOW)
                .setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .build()
        }

        private fun ensureChannel(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(CHANNEL_ID) != null) return

            val channel = NotificationChannel(
                CHANNEL_ID,
                context.getString(R.string.keep_alive_channel_name),
                // LOW: this must never make a sound or vibrate. It is a
                // "the app is still working" indicator, not a user-facing alert.
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = context.getString(R.string.keep_alive_channel_description)
                setShowBadge(false)
            }
            manager.createNotificationChannel(channel)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        try {
            val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            } else {
                0
            }
            ServiceCompat.startForeground(
                this,
                NOTIFICATION_ID,
                buildNotification(this, sessionCount),
                type,
            )
            isRunning = true
        } catch (_: Exception) {
            // e.g. ForegroundServiceStartNotAllowedException when the system
            // refuses a background start. Not fatal: the app keeps working in
            // the foreground, it just loses background protection.
            isRunning = false
        }

        // STICKY: the system restarts the service if the process is killed.
        return START_STICKY
    }

    /**
     * Android 15+ requires services started from the background to stop
     * themselves within a timeout window rather than being killed silently.
     */
    override fun onTimeout(startId: Int) {
        stopSelf()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        stopSelf()
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }
}
