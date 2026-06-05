package com.cloudwebrtc.webrtc;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ServiceInfo;
import android.os.Binder;
import android.os.Build;
import android.os.IBinder;
import android.util.Log;

import androidx.annotation.Nullable;
import androidx.core.app.NotificationCompat;
import androidx.core.app.ServiceCompat;

/**
 * Android 14 (API 34) requires an active foreground service of type
 * FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION before calling
 * MediaProjectionManager.getMediaProjection(resultCode, data). Older
 * flutter_webrtc releases (including 1.4.1) call getMediaProjection from
 * OrientationAwareScreenCapturer.startCapture without ever starting such a
 * service — which is why the screen share crashes on Android 14.
 *
 * This service exists solely to satisfy that requirement. It lives for the
 * duration of one screen-share capture and is stopped when the capturer
 * tears down.
 */
public class ScreenCaptureService extends Service {
    private static final String TAG = "FlutterWebRTC-FGS";
    private static final String CHANNEL_ID = "flutter_webrtc_screen_capture";
    private static final int NOTIFICATION_ID = 9876;

    private final IBinder binder = new LocalBinder();

    public class LocalBinder extends Binder {
        public ScreenCaptureService getService() { return ScreenCaptureService.this; }
    }

    @Override
    public void onCreate() {
        super.onCreate();
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationManager nm = (NotificationManager) getSystemService(Context.NOTIFICATION_SERVICE);
            if (nm != null && nm.getNotificationChannel(CHANNEL_ID) == null) {
                NotificationChannel channel = new NotificationChannel(
                        CHANNEL_ID,
                        "Screen sharing",
                        NotificationManager.IMPORTANCE_LOW
                );
                channel.setDescription("Shown while your screen is being shared in a call");
                nm.createNotificationChannel(channel);
            }
        }
    }

    @Override
    public int onStartCommand(@Nullable Intent intent, int flags, int startId) {
        Notification notification = new NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("Sharing your screen")
                .setContentText("You are sharing your screen in a call")
                .setSmallIcon(android.R.drawable.ic_menu_slideshow)
                .setOngoing(true)
                .setCategory(NotificationCompat.CATEGORY_SERVICE)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .build();
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                ServiceCompat.startForeground(
                        this,
                        NOTIFICATION_ID,
                        notification,
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
                );
            } else {
                startForeground(NOTIFICATION_ID, notification);
            }
            Log.d(TAG, "startForeground(type=mediaProjection) OK");
        } catch (Throwable t) {
            Log.e(TAG, "startForeground FAILED", t);
        }
        return START_NOT_STICKY;
    }

    @Override
    public IBinder onBind(Intent intent) { return binder; }

    @Override
    public void onDestroy() {
        Log.d(TAG, "onDestroy");
        super.onDestroy();
    }
}
