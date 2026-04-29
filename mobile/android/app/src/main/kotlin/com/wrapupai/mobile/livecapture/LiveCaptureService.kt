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
import java.util.concurrent.atomic.AtomicBoolean

class LiveCaptureService : Service() {
    private val stopStarted = AtomicBoolean(false)
    private val serviceStoppedEmitted = AtomicBoolean(false)
    private var mediaProjection: MediaProjection? = null
    private var playbackCapture: SystemPlaybackAudioCapture? = null
    private var microphoneCapture: MicrophoneAudioCapture? = null
    private var audioMixer: LiveAudioMixer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        activeService = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> Unit
            ACTION_STOP -> {
                stopCaptureAndService(reason = "actionStop", startId = startId)
                return START_NOT_STICKY
            }
            else -> {
                stopCaptureAndService(reason = "unknownAction", startId = startId)
                return START_NOT_STICKY
            }
        }

        val config = LiveCaptureConfig.fromIntent(intent)
        stopStarted.set(false)
        serviceStoppedEmitted.set(false)

        return try {
            startAsForeground(config)
            running = true
            LiveCaptureStatusBus.emitStatus(
                "serviceStarted",
                serviceStartedMessage(config),
            )
            startRequestedCaptures(intent, config, startId)
            START_STICKY
        } catch (error: SecurityException) {
            running = false
            val message = error.message
                ?: "Foreground service permission denied for ${foregroundServiceTypeLabel(config)} type."
            LiveCaptureStatusBus.emitError(
                "foregroundServiceSecurityError",
                "${foregroundServiceTypeLabel(config)} foreground service type failed: $message",
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
        stopCaptureAndService(reason = "serviceDestroyed", shouldStopSelf = false)
        if (activeService === this) {
            activeService = null
        }
        super.onDestroy()
    }

    private fun startAsForeground(config: LiveCaptureConfig) {
        ensureNotificationChannel()
        val notification = buildNotification()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                foregroundServiceType(config),
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun startRequestedCaptures(
        intent: Intent,
        config: LiveCaptureConfig,
        startId: Int,
    ) {
        if (config.captureSystemAudio && config.captureMicrophone) {
            startMixedCapture(intent, config, startId)
        } else if (config.captureSystemAudio) {
            startPlaybackCapture(intent, startId)
        } else if (config.captureMicrophone) {
            startMicrophoneCapture(config, startId)
        } else {
            LiveCaptureStatusBus.emitWarning(
                "No Android capture source was enabled.",
                "captureSourceMissing",
            )
            stopCaptureAndService(reason = "captureSourceMissing", startId = startId)
        }
    }

    private fun startPlaybackCapture(
        intent: Intent,
        startId: Int,
        mixer: LiveAudioMixer? = null,
    ) {
        val config = LiveCaptureConfig.fromIntent(intent)
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

                override fun onSystemPcmFrame(
                    samples: ShortArray,
                    sampleCount: Int,
                    sampleRateHz: Int,
                    channelCount: Int,
                ) {
                    mixer?.acceptSystemFrame(
                        samples = samples,
                        sampleCount = sampleCount,
                        sampleRateHz = sampleRateHz,
                        channelCount = channelCount,
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
                    stopCaptureAndService(reason = "playbackError", startId = startId)
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

    private fun startMicrophoneCapture(
        config: LiveCaptureConfig,
        startId: Int,
        mixer: LiveAudioMixer? = null,
    ) {
        microphoneCapture = MicrophoneAudioCapture(
            config = config,
            listener = object : MicrophoneAudioCapture.Listener {
                override fun onMicrophoneCaptureStarting() {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_MICROPHONE_CAPTURE_STARTING,
                        "Starting Android microphone AudioRecord.",
                    )
                }

                override fun onMicrophoneCaptureStarted(
                    sampleRateHz: Int,
                    audioSourceName: String,
                ) {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_MICROPHONE_CAPTURE_STARTED,
                        "Microphone AudioRecord started at $sampleRateHz Hz.",
                        mapOf(
                            "sampleRateHz" to sampleRateHz,
                            "audioSource" to audioSourceName,
                        ),
                    )
                }

                override fun onMicrophoneAudioLevel(
                    level: Double,
                    isSilent: Boolean,
                    sampleRateHz: Int,
                    audioSourceName: String,
                ) {
                    LiveCaptureStatusBus.emitAudioLevel(
                        level = level,
                        isSilent = isSilent,
                        source = LiveCaptureAudioContract.SOURCE_MICROPHONE,
                        sampleRateHz = sampleRateHz,
                        fields = mapOf("audioSource" to audioSourceName),
                    )
                }

                override fun onMicrophonePcmFrame(
                    samples: ShortArray,
                    sampleCount: Int,
                    sampleRateHz: Int,
                    channelCount: Int,
                    audioSourceName: String,
                ) {
                    mixer?.acceptMicrophoneFrame(
                        samples = samples,
                        sampleCount = sampleCount,
                        sampleRateHz = sampleRateHz,
                        channelCount = channelCount,
                        audioSourceName = audioSourceName,
                    )
                }

                override fun onMicrophoneCaptureStatus(
                    status: String,
                    message: String?,
                    fields: Map<String, Any?>,
                ) {
                    LiveCaptureStatusBus.emitStatus(status, message, fields)
                }

                override fun onMicrophoneCaptureWarning(message: String, code: String?) {
                    LiveCaptureStatusBus.emitWarning(message, code)
                }

                override fun onMicrophoneCaptureError(code: String, message: String) {
                    LiveCaptureStatusBus.emitError(code, message)
                    stopCaptureAndService(reason = "microphoneError", startId = startId)
                }

                override fun onMicrophoneCaptureStopped() {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_MICROPHONE_CAPTURE_STOPPED,
                        "Microphone capture stopped.",
                    )
                }
            },
        ).also { capture ->
            capture.start()
        }
    }

    private fun startMixedCapture(intent: Intent, config: LiveCaptureConfig, startId: Int) {
        val mixer = LiveAudioMixer(
            config = config,
            listener = object : LiveAudioMixer.Listener {
                override fun onMixedCaptureStatus(
                    status: String,
                    message: String?,
                    fields: Map<String, Any?>,
                ) {
                    LiveCaptureStatusBus.emitStatus(status, message, fields)
                }

                override fun onMixedAudioLevel(
                    level: Double,
                    isSilent: Boolean,
                    clippingCount: Int,
                    systemFramesBuffered: Int,
                    micFramesBuffered: Int,
                    micDucked: Boolean,
                    effectiveMicGain: Double,
                    effectiveSystemGain: Double,
                ) {
                    LiveCaptureStatusBus.emitAudioLevel(
                        level = level,
                        isSilent = isSilent,
                        source = LiveCaptureAudioContract.SOURCE_MIXED,
                        sampleRateHz = LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
                        fields = mapOf(
                            "channelCount" to LiveCaptureAudioContract.CHANNEL_COUNT,
                            "clippingCount" to clippingCount,
                            "systemFramesBuffered" to systemFramesBuffered,
                            "micFramesBuffered" to micFramesBuffered,
                            "micDucked" to micDucked,
                            "effectiveMicGain" to effectiveMicGain,
                            "effectiveSystemGain" to effectiveSystemGain,
                        ),
                    )
                }

                override fun onMixedPcmFrame(frame: MixedAudioFrame) {
                    LiveCapturePcmBus.emitMixedFrame(frame.samples)
                }

                override fun onMixedCaptureWarning(message: String, code: String?) {
                    LiveCaptureStatusBus.emitWarning(message, code)
                }

                override fun onMixedCaptureStopped() {
                    LiveCaptureStatusBus.emitStatus(
                        LiveCaptureAudioContract.STATUS_MIXED_CAPTURE_STOPPED,
                        "Local native mixer stopped.",
                    )
                }
            },
        )
        audioMixer = mixer
        mixer.start()
        startPlaybackCapture(intent = intent, startId = startId, mixer = mixer)
        startMicrophoneCapture(config = config, startId = startId, mixer = mixer)
    }

    private fun stopCaptureAndService(
        reason: String,
        startId: Int? = null,
        shouldStopSelf: Boolean = true,
    ) {
        if (stopStarted.compareAndSet(false, true)) {
            LiveCaptureStatusBus.emitStatus(
                LiveCaptureAudioContract.STATUS_SERVICE_STOP_REQUESTED,
                "Stopping Android live capture service.",
                mapOf("reason" to reason),
            )

            val capture = playbackCapture
            playbackCapture = null
            capture?.stop()

            val micCapture = microphoneCapture
            microphoneCapture = null
            micCapture?.stop()

            val mixer = audioMixer
            audioMixer = null
            mixer?.stop()

            val projection = mediaProjection
            mediaProjection = null
            try {
                projection?.stop()
            } catch (_: RuntimeException) {
                // Projection shutdown is best-effort during service teardown.
            }

            running = false
            stopForegroundCompat()
            emitServiceStoppedOnce(reason)
        }

        if (shouldStopSelf) {
            if (startId != null) {
                stopSelf(startId)
            } else {
                stopSelf()
            }
        }
    }

    private fun emitServiceStoppedOnce(reason: String) {
        if (serviceStoppedEmitted.compareAndSet(false, true)) {
            LiveCaptureStatusBus.emitStatus(
                "serviceStopped",
                "Android live capture service stopped.",
                mapOf("reason" to reason),
            )
            LiveCaptureStatusBus.emitStopped(reason)
        }
    }

    private fun foregroundServiceType(config: LiveCaptureConfig): Int {
        return when {
            config.captureSystemAudio && !config.captureMicrophone ->
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
            !config.captureSystemAudio && config.captureMicrophone ->
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            config.captureSystemAudio && config.captureMicrophone ->
                ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION or
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
            else -> ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
        }
    }

    private fun foregroundServiceTypeLabel(config: LiveCaptureConfig): String {
        return when {
            config.captureSystemAudio && !config.captureMicrophone -> "mediaProjection"
            !config.captureSystemAudio && config.captureMicrophone -> "microphone"
            config.captureSystemAudio && config.captureMicrophone -> "mediaProjection|microphone"
            else -> "mediaProjection"
        }
    }

    private fun serviceStartedMessage(config: LiveCaptureConfig): String {
        return when {
            config.captureSystemAudio && !config.captureMicrophone ->
                "WrapUp AI is checking Android system audio capture."
            !config.captureSystemAudio && config.captureMicrophone ->
                "WrapUp AI is checking Android microphone capture."
            config.captureSystemAudio && config.captureMicrophone ->
                "WrapUp AI is checking Android mixed audio capture."
            else -> "WrapUp AI is checking Android live capture."
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
        private const val ACTION_STOP = "com.wrapupai.mobile.livecapture.STOP"
        private const val CHANNEL_ID = "wrapup_live_capture"
        private const val NOTIFICATION_ID = 6042
        private const val EXTRA_PROJECTION_RESULT_CODE = "projectionResultCode"
        private const val EXTRA_PROJECTION_DATA = "projectionData"

        @Volatile
        private var running = false

        @Volatile
        private var activeService: LiveCaptureService? = null

        fun isRunning(): Boolean = running

        fun start(
            context: Context,
            resultCode: Int?,
            projectionData: Intent?,
            config: LiveCaptureConfig,
        ) {
            val intent = config.addToIntent(
                Intent(context, LiveCaptureService::class.java)
                    .setAction(ACTION_START),
            )
            if (resultCode != null) {
                intent.putExtra(EXTRA_PROJECTION_RESULT_CODE, resultCode)
            }
            if (projectionData != null) {
                intent.putExtra(EXTRA_PROJECTION_DATA, projectionData)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context): Boolean {
            val intent = Intent(context, LiveCaptureService::class.java)
                .setAction(ACTION_STOP)
            return try {
                context.startService(intent) != null
            } catch (_: RuntimeException) {
                activeService?.let { service ->
                    service.stopCaptureAndService(reason = "directStopFallback")
                    true
                } ?: false
            }
        }
    }
}
