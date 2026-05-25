package com.example.ciro_chat_app

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.os.IBinder
import androidx.core.app.NotificationCompat

class ScreenShareForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "screen_share_channel"
        const val NOTIFICATION_ID = 9001
        const val ACTION_STOP = "com.example.ciro_chat_app.STOP_SCREEN_SHARE"

        /** Set by MainActivity; called when the user taps STOP in the notification. */
        var onStopFromNotification: (() -> Unit)? = null
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            onStopFromNotification?.invoke()
            stopSelf()
            return START_NOT_STICKY
        }

        val stopPendingIntent = PendingIntent.getService(
            this, 0,
            Intent(this, ScreenShareForegroundService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Sharing your screen")
            .setContentText("You are sharing your screen in a call")
            .setSmallIcon(android.R.drawable.ic_menu_slideshow)
            .setOngoing(true)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Stop", stopPendingIntent)
            .build()

        startForeground(NOTIFICATION_ID, notification)
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
