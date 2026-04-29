package com.wrapupai.mobile.livecapture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder
import com.wrapupai.mobile.MainActivity
import com.wrapupai.mobile.R

class LiveCaptureService : Service() {
    private var mediaProjection: MediaProjection? = null
    private var playbackCapture: SystemPlaybackAudioCapture? = null

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
                "WrapUp AI is checking Android system audio capture.",
            )
            startPlaybackCapture(intent, startId)
            START_STICKY
        } catch (error: SecurityException) {
            running = false
            val message = error.message
                ?: "Foreground service permission denied for mediaProjection type."
            LiveCaptureStatusBus.emitError(
                "foregroundServiceSecurityError",
                "mediaProjection foreground service type failed: $message",
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
        playbackCapture?.stop()
        playbackCapture = null
        mediaProjection?.stop()
        mediaProjection = null
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
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startPlaybackCapture(intent: Intent, startId: Int) {
        val config = LiveCaptureConfig.fromIntent(intent)
        if (config.captureMicrophone) {
            LiveCaptureStatusBus.emitWarning(
                "Microphone capture is not enabled in Phase 6F.",
                "microphoneCaptureDeferred",
            )
        }
        if (!config.captureSystemAudio) {
            LiveCaptureStatusBus.emitWarning(
                "System playback capture is disabled in this capture config.",
                "systemPlaybackDisabled",
            )
            return
        }

        val projectionData = projectionDataFromIntent(intent)
        val resultCode = intent.getIntExtra(
            EXTRA_PROJECTION_RESULT_CODE,
            Activity.RESULT_CANCELED,
        )
        if (projectionData == null || resultCode != Activity.RESULT_OK) {
            LiveCaptureStatusBus.emitError(
                LiveCaptureAudioContract.ERROR_PROJECTION_UNAVAILABLE,
                "MediaProjection permission data was not available.",
            )
            stopSelf(startId)
            return
        }

        val projectionManager = getSystemService(
            Context.MEDIA_PROJECTION_SERVICE,
        ) as? MediaProjectionManager
        if (projectionManager == null) {
            LiveCaptureStatusBus.emitError(
                LiveCaptureAudioContract.ERROR_PROJECTION_UNAVAILABLE,
                "MediaProjectionManager is not available on this device.",
            )
            stopSelf(startId)
            return
        }

        val projection = try {
            projectionManager.getMediaProjection(resultCode, projectionData)
        } catch (error: SecurityException) {
            LiveCaptureStatusBus.emitError(
                LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_SECURITY,
                error.message ?: "MediaProjection could not be opened.",
            )
            stopSelf(startId)
            return
        }
        if (projection == null) {
            LiveCaptureStatusBus.emitError(
                LiveCaptureAudioContract.ERROR_PROJECTION_UNAVAILABLE,
                "MediaProjection could not be opened.",
            )
            stopSelf(startId)
            return
        }
        mediaProjection = projection

        playbackCapture = SystemPlaybackAudioCapture(
            mediaProjection = projection,
            config = config,
            listener = object : SystemPlaybackAudioCapture.Listener {
                override fun onPlaybackCaptureStarting() {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_PLAYBACK_CAPTURE_STARTING,
                        "Starting Android system playback AudioRecord.",
                    )
                }

                override fun onPlaybackCaptureStarted(sampleRateHz: Int) {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_PLAYBACK_CAPTURE_STARTED,
                        "System playback AudioRecord started at $sampleRateHz Hz.",
                        mapOf("sampleRateHz" to sampleRateHz),
                    )
                }

                override fun onPlaybackAudioLevel(
                    level: Double,
                    isSilent: Boolean,
                    sampleRateHz: Int,
                ) {
                    LiveCaptureStatusBus.emitAudioLevel(
                        level = level,
                        isSilent = isSilent,
                        source = LiveCaptureAudioContract.SOURCE_SYSTEM_PLAYBACK,
                        sampleRateHz = sampleRateHz,
                    )
                }

                override fun onPlaybackCaptureStatus(
                    status: String,
                    message: String?,
                    fields: Map<String, Any?>,
                ) {
                    LiveCaptureStatusBus.emitStatus(status, message, fields)
                }

                override fun onPlaybackCaptureWarning(message: String, code: String?) {
                    LiveCaptureStatusBus.emitWarning(message, code)
                }

                override fun onPlaybackCaptureError(code: String, message: String) {
                    LiveCaptureStatusBus.emitError(code, message)
                    stopSelf(startId)
                }

                override fun onPlaybackCaptureStopped() {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_PLAYBACK_CAPTURE_STOPPED,
                        "System playback capture stopped.",
                    )
                }
            },
        ).also { capture ->
            capture.start()
        }
    }

    private fun projectionDataFromIntent(intent: Intent): Intent? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_PROJECTION_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_PROJECTION_DATA)
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
            .setContentText("Checking Android system audio capture")
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
