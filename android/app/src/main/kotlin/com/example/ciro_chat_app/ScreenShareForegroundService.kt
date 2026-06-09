package com.example.ciro_chat_app

import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

class ScreenShareForegroundService : Service() {

    companion object {
        const val CHANNEL_ID = "screen_share_channel"
        const val NOTIFICATION_ID = 9001
        const val ACTION_STOP = "com.example.ciro_chat_app.STOP_SCREEN_SHARE"
        const val ACTION_FGS_READY = "com.example.ciro_chat_app.SCREEN_SHARE_FGS_READY"

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

        Log.d("ScreenShareFGS", "onStartCommand — calling startForeground(type=mediaProjection)")
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                    this,
                    NOTIFICATION_ID,
                    notification,
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
            Log.d("ScreenShareFGS", "startForeground returned without exception")
        } catch (t: Throwable) {
            Log.e("ScreenShareFGS", "startForeground FAILED", t)
        }
        sendBroadcast(Intent(ACTION_FGS_READY).setPackage(packageName))
        Log.d("ScreenShareFGS", "sent ACTION_FGS_READY broadcast")
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
