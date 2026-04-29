package com.wrapupai.mobile.livecapture

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

object LiveCaptureStatusBus {
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null

    fun attach(sink: EventChannel.EventSink) {
        mainHandler.post {
            eventSink = sink
            emitStatus("idle")
        }
    }

    fun detach() {
        mainHandler.post {
            eventSink = null
        }
    }

    fun emitStatus(
        status: String,
        message: String? = null,
        fields: Map<String, Any?> = emptyMap(),
    ) {
        emit(
            type = "status",
            message = message,
            fields = mapOf("status" to status) + fields,
        )
    }

    fun emitWarning(message: String, code: String? = null) {
        emit(
            type = "warning",
            message = message,
            fields = code?.let { mapOf("code" to it) } ?: emptyMap(),
        )
    }

    fun emitError(code: String, message: String) {
        emit(
            type = "error",
            message = message,
            fields = mapOf("code" to code),
        )
    }

    fun emitAudioLevel(
        level: Double,
        isSilent: Boolean,
        source: String,
        sampleRateHz: Int,
    ) {
        emit(
            type = "audioLevel",
            fields = mapOf(
                "level" to level,
                "isSilent" to isSilent,
                "source" to source,
                "sampleRateHz" to sampleRateHz,
            ),
        )
    }

    fun emitStopped(reason: String? = null) {
        emit(
            type = "stopped",
            message = reason,
            fields = reason?.let { mapOf("reason" to it) } ?: emptyMap(),
        )
    }

    fun emitProjectionGranted() {
        emitStatus("projectionGranted")
    }

    fun emitProjectionDenied() {
        emitStatus("projectionDenied", "MediaProjection permission was denied.")
    }

    private fun emit(
        type: String,
        message: String? = null,
        fields: Map<String, Any?> = emptyMap(),
    ) {
        val event = linkedMapOf<String, Any?>("type" to type)
        if (message != null) {
            event["message"] = message
        }
        event.putAll(fields)

        mainHandler.post {
            eventSink?.success(event)
        }
    }
}
