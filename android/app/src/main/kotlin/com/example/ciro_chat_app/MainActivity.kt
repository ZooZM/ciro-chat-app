package com.example.ciro_chat_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CHANNEL = "com.example.ciro_chat_app/screen_share_service"
    }

    private var screenSharePending = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createScreenShareNotificationChannel()
        createCallNotificationChannel()
    }

    @Deprecated("Required for Android 14 MediaProjection FGS timing.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        Log.d("ScreenShareFGS", "onActivityResult: req=$requestCode result=$resultCode pending=$screenSharePending")
        if (screenSharePending && resultCode == RESULT_OK) {
            screenSharePending = false
            // Start the FGS but DO NOT call super.onActivityResult yet — that
            // dispatches the result to flutter_webrtc's fragment, which will
            // immediately call getMediaProjection() and crash if the FGS hasn't
            // finished calling startForeground(..., type=mediaProjection) yet.
            // startForegroundService is async; we must wait for the broadcast
            // the service fires once startForeground has actually returned.
            val handler = Handler(Looper.getMainLooper())
            val timeout = Runnable {
                Log.w("ScreenShareFGS", "TIMEOUT after 3s — FGS broadcast never arrived; dispatching anyway")
                super@MainActivity.onActivityResult(requestCode, resultCode, data)
            }
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    Log.d("ScreenShareFGS", "FGS_READY broadcast received → dispatching to fragment")
                    handler.removeCallbacks(timeout)
                    try { unregisterReceiver(this) } catch (_: Exception) {}
                    super@MainActivity.onActivityResult(requestCode, resultCode, data)
                }
            }
            val filter = IntentFilter(ScreenShareForegroundService.ACTION_FGS_READY)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
            } else {
                @Suppress("UnspecifiedRegisterReceiverFlag")
                registerReceiver(receiver, filter)
            }
            // Hard cap so a service failure can't leave the consent grant orphaned.
            handler.postDelayed(timeout, 3000)

            val fgsIntent = Intent(this, ScreenShareForegroundService::class.java)
            Log.d("ScreenShareFGS", "calling startForegroundService")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(fgsIntent)
            } else {
                startService(fgsIntent)
            }
            return
        }
        if (screenSharePending) screenSharePending = false
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)

        ScreenShareForegroundService.onStopFromNotification = {
            channel.invokeMethod("onStopFromNotification", null)
        }

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    // Android 14: do NOT start the FGS here — validation
                    // would fail (no consent yet). Flag intent and let
                    // onActivityResult start it once the system consent
                    // dialog returns RESULT_OK, before flutter_webrtc's
                    // fragment runs getMediaProjection.
                    screenSharePending = true
                    Log.d("ScreenShareFGS", "channel 'start' → screenSharePending=true")
                    result.success(null)
                }
                "stop" -> {
                    screenSharePending = false
                    stopService(Intent(this, ScreenShareForegroundService::class.java))
                    result.success(null)
                }
                "startCallService" -> {
                    val intent = Intent(this, CallForegroundService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                "stopCallService" -> {
                    stopService(Intent(this, CallForegroundService::class.java))
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun createScreenShareNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                ScreenShareForegroundService.CHANNEL_ID,
                "Screen Sharing",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shown while sharing your screen during a call"
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    private fun createCallNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CallForegroundService.CHANNEL_ID,
                "Active Call",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shown while you are in an active voice or video call"
                setShowBadge(false)
            }
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }
}
