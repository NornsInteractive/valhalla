package com.antigravity.valhalla.valhalla

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/**
 * Posts "transfer finished" notifications.
 *
 * Separate from [SshKeepAliveService] because the two have opposite lifecycles:
 * the keep-alive notification is a long-lived, ongoing service notification,
 * whereas this one is a one-shot alert that the user dismisses. Sharing
 * channels would also mean the user cannot silence one without the other.
 *
 * The notification is posted from Kotlin rather than Dart so it still appears
 * when the Flutter engine is backgrounded. Tapping it opens [MainActivity] with
 * [EXTRA_OPEN_TRANSFERS] set; the Dart side reads that via MethodChannel and
 * switches to the transfer list.
 */
object TransferNotifier {

    private const val CHANNEL_ID = "valhalla_transfers"
    private const val NOTIFICATION_ID = 4203

    /** Extra read by the Dart side to decide which tab to show on resume. */
    const val EXTRA_OPEN_TRANSFERS = "open_transfers"

    /**
     * Post a completion notification.
     *
     * [completedCount] is the number of transfers finished since the last
     * notification, so a batch of downloads collapses into one alert instead
     * of spamming the shade.
     */
    fun notifyCompleted(context: Context, completedCount: Int) {
        val manager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        ensureChannel(context, manager)

        // The user can turn this channel off in system settings; posting to a
        // disabled channel is a no-op rather than an error, but checking first
        // avoids a pointless PendingIntent allocation on every completion.
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            return
        }

        val openTransfers = PendingIntent.getActivity(
            context,
            // Distinct request code from the keep-alive notification: two
            // PendingIntents with the same code but different extras would
            // otherwise collide and deliver the wrong intent.
            1,
            Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra(EXTRA_OPEN_TRANSFERS, true)
            },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val title = context.resources.getQuantityString(
            R.plurals.transfer_complete_title,
            completedCount,
            completedCount,
        )

        val notification = NotificationCompat.Builder(context, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(context.getString(R.string.transfer_complete_body))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentIntent(openTransfers)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(NotificationCompat.CATEGORY_STATUS)
            .build()

        try {
            manager.notify(NOTIFICATION_ID, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS revoked between the check and the post.
            // Not fatal: the transfer itself already succeeded.
        }
    }

    private fun ensureChannel(context: Context, manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            context.getString(R.string.transfer_complete_channel_name),
            // DEFAULT: unlike the keep-alive indicator, this *is* a user-facing
            // result the user asked for, so it may make a sound.
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = context.getString(R.string.transfer_complete_channel_description)
        }
        manager.createNotificationChannel(channel)
    }
}
