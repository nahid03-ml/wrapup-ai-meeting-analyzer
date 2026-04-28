package com.wrapupai.mobile.livecapture

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.os.Build
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class LiveCaptureChannels(
    private val activity: Activity,
    messenger: BinaryMessenger,
) {
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL_NAME)
    private val statusEventChannel = EventChannel(messenger, STATUS_EVENT_CHANNEL_NAME)
    private val pcmEventChannel = EventChannel(messenger, PCM_EVENT_CHANNEL_NAME)
    private val projectionManager: MediaProjectionManager? by lazy {
        activity.getSystemService(Context.MEDIA_PROJECTION_SERVICE) as? MediaProjectionManager
    }

    private var pendingProjectionResult: MethodChannel.Result? = null
    private var projectionResultCode: Int? = null
    private var projectionData: Intent? = null
    private var pcmSink: EventChannel.EventSink? = null

    fun register() {
        methodChannel.setMethodCallHandler(::handleMethodCall)
        statusEventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    LiveCaptureStatusBus.attach(events)
                }

                override fun onCancel(arguments: Any?) {
                    LiveCaptureStatusBus.detach()
                }
            },
        )
        pcmEventChannel.setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                    pcmSink = events
                }

                override fun onCancel(arguments: Any?) {
                    pcmSink = null
                }
            },
        )
    }

    fun dispose() {
        LiveCaptureService.stop(activity)
        pendingProjectionResult?.error(
            "projection_disposed",
            "MediaProjection request was disposed.",
            null,
        )
        pendingProjectionResult = null
        projectionResultCode = null
        projectionData = null
        pcmSink = null
        methodChannel.setMethodCallHandler(null)
        statusEventChannel.setStreamHandler(null)
        pcmEventChannel.setStreamHandler(null)
        LiveCaptureStatusBus.detach()
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_MEDIA_PROJECTION) {
            return false
        }

        val result = pendingProjectionResult
        pendingProjectionResult = null

        if (resultCode == Activity.RESULT_OK && data != null) {
            projectionResultCode = resultCode
            projectionData = data
            LiveCaptureStatusBus.emitProjectionGranted()
            result?.success(
                mapOf(
                    "granted" to true,
                    "message" to "MediaProjection permission granted.",
                ),
            )
            return true
        }

        projectionResultCode = null
        projectionData = null
        LiveCaptureStatusBus.emitProjectionDenied()
        result?.success(
            mapOf(
                "granted" to false,
                "message" to "MediaProjection permission denied.",
            ),
        )
        return true
    }

    private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isSupported" -> result.success(isSupported())
            "requestProjection" -> requestProjection(result)
            "startCapture" -> startCapture(call.arguments, result)
            "stopCapture" -> stopCapture(result)
            "dispose" -> {
                LiveCaptureService.stop(activity)
                disposeCaptureState()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestProjection(result: MethodChannel.Result) {
        if (!isSupported()) {
            result.success(
                mapOf(
                    "granted" to false,
                    "message" to "Android device audio capture requires Android 10 or newer.",
                ),
            )
            return
        }
        if (pendingProjectionResult != null) {
            result.error(
                "projection_pending",
                "A MediaProjection request is already in progress.",
                null,
            )
            return
        }

        val manager = projectionManager
        if (manager == null) {
            result.error(
                "projection_unavailable",
                "MediaProjectionManager is not available on this device.",
                null,
            )
            return
        }

        pendingProjectionResult = result
        LiveCaptureStatusBus.emitStatus("requestingProjection")
        try {
            activity.startActivityForResult(
                manager.createScreenCaptureIntent(),
                REQUEST_MEDIA_PROJECTION,
            )
        } catch (error: RuntimeException) {
            pendingProjectionResult = null
            LiveCaptureStatusBus.emitError(
                "projection_request_failed",
                error.message ?: "MediaProjection request could not be started.",
            )
            result.error(
                "projection_request_failed",
                error.message ?: "MediaProjection request could not be started.",
                null,
            )
        }
    }

    private fun startCapture(arguments: Any?, result: MethodChannel.Result) {
        if (!isSupported()) {
            result.error(
                "unsupported",
                "Android device audio capture requires Android 10 or newer.",
                null,
            )
            return
        }

        val resultCode = projectionResultCode
        val data = projectionData
        if (resultCode == null || data == null) {
            result.error(
                "projection_required",
                "MediaProjection permission must be granted before starting capture.",
                null,
            )
            return
        }

        val config = LiveCaptureConfig.fromArguments(arguments)
        projectionResultCode = null
        projectionData = null
        LiveCaptureStatusBus.emitStatus("startingService")

        try {
            LiveCaptureService.start(
                context = activity,
                resultCode = resultCode,
                projectionData = data,
                config = config,
            )
            result.success(null)
        } catch (error: SecurityException) {
            LiveCaptureStatusBus.emitError(
                "foreground_service_security",
                error.message ?: "Foreground service permission denied.",
            )
            result.error(
                "foreground_service_security",
                error.message ?: "Foreground service permission denied.",
                null,
            )
        } catch (error: RuntimeException) {
            LiveCaptureStatusBus.emitError(
                "foreground_service_failed",
                error.message ?: "Foreground service could not start.",
            )
            result.error(
                "foreground_service_failed",
                error.message ?: "Foreground service could not start.",
                null,
            )
        }
    }

    private fun stopCapture(result: MethodChannel.Result) {
        LiveCaptureStatusBus.emitStatus("stoppingService")
        val stopped = LiveCaptureService.stop(activity)
        if (!stopped && !LiveCaptureService.isRunning()) {
            LiveCaptureStatusBus.emitStopped("serviceNotRunning")
        }
        disposeCaptureState()
        result.success(null)
    }

    private fun disposeCaptureState() {
        pendingProjectionResult?.error(
            "projection_disposed",
            "MediaProjection request was disposed.",
            null,
        )
        projectionResultCode = null
        projectionData = null
        pendingProjectionResult = null
    }

    private fun isSupported(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && projectionManager != null
    }

    companion object {
        const val METHOD_CHANNEL_NAME = "wrapup/live_capture"
        const val STATUS_EVENT_CHANNEL_NAME = "wrapup/live_capture_status"
        const val PCM_EVENT_CHANNEL_NAME = "wrapup/live_capture_pcm"
        private const val REQUEST_MEDIA_PROJECTION = 6042
    }
}
