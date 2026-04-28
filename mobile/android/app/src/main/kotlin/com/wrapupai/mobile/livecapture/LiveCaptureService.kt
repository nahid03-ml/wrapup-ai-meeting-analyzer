package com.wrapupai.mobile.livecapture

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
import com.wrapupai.mobile.MainActivity
import com.wrapupai.mobile.R

class LiveCaptureService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action != ACTION_START) {
            stopSelf(startId)
            return START_NOT_STICKY
        }

        return try {
            startAsForeground()
            running = true
            LiveCaptureStatusBus.emitStatus(
                "serviceStarted",
                "WrapUp AI is preparing Android live capture.",
            )
            START_STICKY
        } catch (error: SecurityException) {
            running = false
            LiveCaptureStatusBus.emitError(
                "foregroundServiceSecurityError",
                error.message ?: "Foreground service permission denied.",
            )
            stopSelf(startId)
            START_NOT_STICKY
        } catch (error: RuntimeException) {
            running = false
            LiveCaptureStatusBus.emitError(
                "serviceFailed",
                error.message ?: "Foreground service could not start.",
            )
            stopSelf(startId)
            START_NOT_STICKY
        }
    }

    override fun onDestroy() {
        running = false
        stopForegroundCompat()
        LiveCaptureStatusBus.emitStatus("serviceStopped")
        LiveCaptureStatusBus.emitStopped("serviceStopped")
        super.onDestroy()
    }

    private fun startAsForeground() {
        ensureNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(): Notification {
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }

        return builder
            .setContentTitle("WrapUp AI live capture")
            .setContentText("WrapUp AI is preparing live capture")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(NotificationManager::class.java)
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) {
            return
        }
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Live capture",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Foreground notification for WrapUp AI live capture."
        }
        manager.createNotificationChannel(channel)
    }

    private fun stopForegroundCompat() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            stopForeground(STOP_FOREGROUND_REMOVE)
        } else {
            @Suppress("DEPRECATION")
            stopForeground(true)
        }
    }

    companion object {
        private const val ACTION_START = "com.wrapupai.mobile.livecapture.START"
        private const val CHANNEL_ID = "wrapup_live_capture"
        private const val NOTIFICATION_ID = 6042
        private const val EXTRA_PROJECTION_RESULT_CODE = "projectionResultCode"
        private const val EXTRA_PROJECTION_DATA = "projectionData"

        @Volatile
        private var running = false

        fun isRunning(): Boolean = running

        fun start(
            context: Context,
            resultCode: Int,
            projectionData: Intent,
            config: LiveCaptureConfig,
        ) {
            val intent = config.addToIntent(
                Intent(context, LiveCaptureService::class.java)
                    .setAction(ACTION_START)
                    .putExtra(EXTRA_PROJECTION_RESULT_CODE, resultCode)
                    .putExtra(EXTRA_PROJECTION_DATA, projectionData),
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context): Boolean {
            return context.stopService(Intent(context, LiveCaptureService::class.java))
        }
    }
}
