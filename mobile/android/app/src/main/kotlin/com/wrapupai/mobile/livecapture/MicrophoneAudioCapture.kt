package com.wrapupai.mobile.livecapture

import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.media.audiofx.AutomaticGainControl
import android.media.audiofx.NoiseSuppressor
import android.os.SystemClock
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicBoolean

class MicrophoneAudioCapture(
    private val config: LiveCaptureConfig,
    private val listener: Listener,
) {
    interface Listener {
        fun onMicrophoneCaptureStarting()
        fun onMicrophoneCaptureStarted(sampleRateHz: Int, audioSourceName: String)
        fun onMicrophoneAudioLevel(
            level: Double,
            isSilent: Boolean,
            sampleRateHz: Int,
            audioSourceName: String,
        )
        fun onMicrophonePcmFrame(
            samples: ShortArray,
            sampleCount: Int,
            sampleRateHz: Int,
            channelCount: Int,
            audioSourceName: String,
        ) = Unit

        fun onMicrophoneCaptureStatus(
            status: String,
            message: String? = null,
            fields: Map<String, Any?> = emptyMap(),
        )

        fun onMicrophoneCaptureWarning(message: String, code: String? = null)
        fun onMicrophoneCaptureError(code: String, message: String)
        fun onMicrophoneCaptureStopped()
    }

    private val running = AtomicBoolean(false)
    private val stoppedEmitted = AtomicBoolean(false)
    private val released = AtomicBoolean(false)
    private val levelMeter = AudioLevelMeter()

    @Volatile
    private var audioRecord: AudioRecord? = null

    @Volatile
    private var executor: ExecutorService? = null
    private var acousticEchoCanceler: AcousticEchoCanceler? = null
    private var noiseSuppressor: NoiseSuppressor? = null
    private var automaticGainControl: AutomaticGainControl? = null

    fun start() {
        if (!running.compareAndSet(false, true)) {
            return
        }
        stoppedEmitted.set(false)
        released.set(false)

        listener.onMicrophoneCaptureStarting()

        val selectedRecord = try {
            buildAudioRecord()
        } catch (error: SecurityException) {
            running.set(false)
            listener.onMicrophoneCaptureError(
                LiveCaptureAudioContract.ERROR_MICROPHONE_CAPTURE_SECURITY,
                error.message ?: "Microphone permission was rejected.",
            )
            emitStoppedOnce()
            return
        }
        if (selectedRecord == null) {
            running.set(false)
            listener.onMicrophoneCaptureError(
                LiveCaptureAudioContract.ERROR_MICROPHONE_AUDIO_RECORD_INIT_FAILED,
                "Microphone AudioRecord could not find a supported format.",
            )
            emitStoppedOnce()
            return
        }

        val record = selectedRecord.audioRecord
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            running.set(false)
            record.release()
            released.set(true)
            listener.onMicrophoneCaptureError(
                LiveCaptureAudioContract.ERROR_MICROPHONE_AUDIO_RECORD_INIT_FAILED,
                "Microphone AudioRecord initialized in an invalid state.",
            )
            emitStoppedOnce()
            return
        }

        audioRecord = record
        val audioEffectsState = configureAudioEffects(record)
        listener.onMicrophoneCaptureStatus(
            LiveCaptureAudioContract.STATUS_MICROPHONE_AUDIO_RECORD_BUILT,
            "Microphone AudioRecord was built.",
            mapOf(
                "sampleRateHz" to selectedRecord.sampleRateHz,
                "channelCount" to selectedRecord.channelCount,
                "bufferSizeBytes" to selectedRecord.bufferSizeBytes,
                "recordingState" to record.recordingState,
                "audioSource" to selectedRecord.audioSourceName,
            ) + audioEffectsState.fields(),
        )
        emitAudioEffectStatuses(audioEffectsState)

        executor = Executors.newSingleThreadExecutor(CaptureThreadFactory)
        executor?.execute {
            readLoop(
                record = record,
                sampleRateHz = selectedRecord.sampleRateHz,
                channelCount = selectedRecord.channelCount,
                bufferSizeBytes = selectedRecord.bufferSizeBytes,
                readBufferShorts = selectedRecord.readBufferShorts,
                audioSourceName = selectedRecord.audioSourceName,
            )
        }
    }

    fun stop() {
        listener.onMicrophoneCaptureStatus(
            LiveCaptureAudioContract.STATUS_MICROPHONE_CAPTURE_STOP_REQUESTED,
            "Stopping Android microphone capture.",
        )
        running.set(false)
        val record = audioRecord
        try {
            if (record?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                record.stop()
            }
        } catch (_: IllegalStateException) {
            // The read loop releases the record; stop may race with natural shutdown.
        }
        releaseRecord(record)
        executor?.shutdownNow()
        emitStoppedOnce()
    }

    private fun buildAudioRecord(): SelectedRecord? {
        val sampleRates = listOf(
            config.sampleRateHz,
            LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
            48000,
            44100,
        ).distinct().filter { it > 0 }
        val audioSources = if (config.captureSystemAudio && config.captureMicrophone) {
            listOf(
                MediaRecorder.AudioSource.VOICE_COMMUNICATION to "VOICE_COMMUNICATION",
                MediaRecorder.AudioSource.VOICE_RECOGNITION to "VOICE_RECOGNITION",
                MediaRecorder.AudioSource.MIC to "MIC",
            )
        } else {
            listOf(
                MediaRecorder.AudioSource.VOICE_RECOGNITION to "VOICE_RECOGNITION",
                MediaRecorder.AudioSource.MIC to "MIC",
            )
        }

        for ((audioSource, audioSourceName) in audioSources) {
            for (sampleRateHz in sampleRates) {
                val minBufferSize = AudioRecord.getMinBufferSize(
                    sampleRateHz,
                    AudioFormat.CHANNEL_IN_MONO,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                if (minBufferSize <= 0) {
                    continue
                }

                val readBufferShorts = maxOf(sampleRateHz / 20, 320)
                val requestedBufferBytes = maxOf(
                    minBufferSize * 2,
                    readBufferShorts * LiveCaptureAudioContract.BYTES_PER_SAMPLE,
                )
                val audioFormat = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRateHz)
                    .setChannelMask(AudioFormat.CHANNEL_IN_MONO)
                    .build()
                val record = try {
                    AudioRecord.Builder()
                        .setAudioSource(audioSource)
                        .setAudioFormat(audioFormat)
                        .setBufferSizeInBytes(requestedBufferBytes)
                        .build()
                } catch (error: SecurityException) {
                    throw error
                } catch (_: RuntimeException) {
                    null
                }

                if (record?.state == AudioRecord.STATE_INITIALIZED) {
                    return SelectedRecord(
                        audioRecord = record,
                        sampleRateHz = sampleRateHz,
                        channelCount = 1,
                        bufferSizeBytes = requestedBufferBytes,
                        readBufferShorts = requestedBufferBytes /
                            LiveCaptureAudioContract.BYTES_PER_SAMPLE,
                        audioSourceName = audioSourceName,
                    )
                }
                record?.release()
            }
        }

        return null
    }

    private fun readLoop(
        record: AudioRecord,
        sampleRateHz: Int,
        channelCount: Int,
        bufferSizeBytes: Int,
        readBufferShorts: Int,
        audioSourceName: String,
    ) {
        val buffer = ShortArray(readBufferShorts)
        var readStartedAtMs = 0L
        var firstFrameReadAtMs = 0L
        var lastNonSilentAtMs = 0L
        var lastLevelEventAtMs = 0L
        var lastNoDataEventAtMs = 0L
        var noFrameWarningEmitted = false
        var silentWarningEmitted = false
        var audioDetectedEmitted = false

        try {
            try {
                listener.onMicrophoneCaptureStatus(
                    LiveCaptureAudioContract.STATUS_MICROPHONE_AUDIO_RECORD_START_REQUESTED,
                    "Starting microphone AudioRecord.",
                    mapOf(
                        "sampleRateHz" to sampleRateHz,
                        "channelCount" to channelCount,
                        "bufferSizeBytes" to bufferSizeBytes,
                        "recordingState" to record.recordingState,
                        "audioSource" to audioSourceName,
                    ),
                )
                record.startRecording()
            } catch (error: SecurityException) {
                running.set(false)
                listener.onMicrophoneCaptureError(
                    LiveCaptureAudioContract.ERROR_MICROPHONE_CAPTURE_SECURITY,
                    error.message ?: "Microphone AudioRecord start was rejected.",
                )
                return
            } catch (error: IllegalStateException) {
                running.set(false)
                listener.onMicrophoneCaptureError(
                    LiveCaptureAudioContract.ERROR_MICROPHONE_AUDIO_RECORD_START_FAILED,
                    error.message ?: "Microphone AudioRecord could not start recording.",
                )
                return
            }

            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                running.set(false)
                listener.onMicrophoneCaptureError(
                    LiveCaptureAudioContract.ERROR_MICROPHONE_AUDIO_RECORD_START_FAILED,
                    "Microphone AudioRecord did not enter recording state. recordingState=${record.recordingState}",
                )
                return
            }

            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_AUDIO_RECORD_RECORDING,
                "Microphone AudioRecord entered recording state.",
                mapOf(
                    "recordingState" to record.recordingState,
                    "audioSource" to audioSourceName,
                ),
            )
            listener.onMicrophoneCaptureStarted(sampleRateHz, audioSourceName)
            readStartedAtMs = SystemClock.elapsedRealtime()
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_READ_STARTED,
                "Microphone capture read loop started.",
                mapOf(
                    "recordingState" to record.recordingState,
                    "audioSource" to audioSourceName,
                ),
            )

            while (running.get()) {
                val read = try {
                    record.read(buffer, 0, buffer.size, AudioRecord.READ_NON_BLOCKING)
                } catch (error: IllegalStateException) {
                    if (running.get()) {
                        listener.onMicrophoneCaptureError(
                            LiveCaptureAudioContract.ERROR_MICROPHONE_CAPTURE_READ_FAILED,
                            error.message ?: "Microphone AudioRecord read failed.",
                        )
                    }
                    break
                }
                val nowMs = SystemClock.elapsedRealtime()
                if (read > 0) {
                    listener.onMicrophonePcmFrame(
                        samples = buffer.copyOf(read),
                        sampleCount = read,
                        sampleRateHz = sampleRateHz,
                        channelCount = channelCount,
                        audioSourceName = audioSourceName,
                    )

                    if (firstFrameReadAtMs == 0L) {
                        firstFrameReadAtMs = nowMs
                        listener.onMicrophoneCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MICROPHONE_FIRST_FRAME_READ,
                            "First microphone audio frame was read.",
                            mapOf(
                                "readResult" to read,
                                "recordingState" to record.recordingState,
                                "sampleRateHz" to sampleRateHz,
                                "audioSource" to audioSourceName,
                            ),
                        )
                    }

                    val level = levelMeter.calculate(buffer, read)
                    if (!level.isSilent) {
                        lastNonSilentAtMs = nowMs
                        if (!audioDetectedEmitted || silentWarningEmitted) {
                            listener.onMicrophoneCaptureStatus(
                                LiveCaptureAudioContract.STATUS_MICROPHONE_AUDIO_DETECTED,
                                "Microphone audio detected.",
                                mapOf("audioSource" to audioSourceName),
                            )
                        }
                        audioDetectedEmitted = true
                        silentWarningEmitted = false
                    }

                    if (
                        !silentWarningEmitted &&
                        level.isSilent &&
                        nowMs - firstFrameReadAtMs >= LiveCaptureAudioContract.SILENCE_WARNING_MS &&
                        (lastNonSilentAtMs == 0L ||
                            nowMs - lastNonSilentAtMs >= LiveCaptureAudioContract.SILENCE_WARNING_MS)
                    ) {
                        silentWarningEmitted = true
                        listener.onMicrophoneCaptureWarning(
                            "No microphone audio detected. Check microphone permission, mute state, or speak closer to the device.",
                            LiveCaptureAudioContract.WARNING_MICROPHONE_SILENT,
                        )
                    }

                    if (nowMs - lastLevelEventAtMs >= LiveCaptureAudioContract.LEVEL_EMIT_INTERVAL_MS) {
                        lastLevelEventAtMs = nowMs
                        listener.onMicrophoneAudioLevel(
                            level = level.level,
                            isSilent = level.isSilent,
                            sampleRateHz = sampleRateHz,
                            audioSourceName = audioSourceName,
                        )
                    }
                } else if (read == 0) {
                    if (
                        nowMs - lastNoDataEventAtMs >=
                        LiveCaptureAudioContract.NO_DATA_STATUS_INTERVAL_MS
                    ) {
                        lastNoDataEventAtMs = nowMs
                        listener.onMicrophoneCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MICROPHONE_READ_NO_DATA,
                            "Microphone capture read returned no data yet.",
                            mapOf(
                                "readResult" to read,
                                "recordingState" to record.recordingState,
                                "audioSource" to audioSourceName,
                            ),
                        )
                    }
                    if (
                        !noFrameWarningEmitted &&
                        firstFrameReadAtMs == 0L &&
                        nowMs - readStartedAtMs >= LiveCaptureAudioContract.NO_FRAME_WARNING_MS
                    ) {
                        noFrameWarningEmitted = true
                        listener.onMicrophoneCaptureWarning(
                            "Microphone capture started but no audio frames were read.",
                            LiveCaptureAudioContract.WARNING_MICROPHONE_CAPTURE_NO_FRAMES,
                        )
                    }
                    try {
                        Thread.sleep(20L)
                    } catch (_: InterruptedException) {
                        Thread.currentThread().interrupt()
                        break
                    }
                } else if (read < 0) {
                    if (running.get()) {
                        listener.onMicrophoneCaptureError(
                            LiveCaptureAudioContract.ERROR_MICROPHONE_CAPTURE_READ_FAILED,
                            "Microphone AudioRecord read failed with code $read.",
                        )
                    }
                    break
                }
            }
        } finally {
            running.set(false)
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_READ_STOPPED,
                "Microphone capture read loop stopped.",
                mapOf("audioSource" to audioSourceName),
            )
            releaseRecord(record)
            emitStoppedOnce()
        }
    }

    private fun releaseRecord(record: AudioRecord?) {
        if (record == null || !released.compareAndSet(false, true)) {
            return
        }
        releaseAudioEffects()
        try {
            if (record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                record.stop()
            }
        } catch (_: IllegalStateException) {
            // The record may already be stopped while the service is shutting down.
        }
        try {
            record.release()
        } catch (_: RuntimeException) {
            // Release is best-effort during service teardown.
        }
        if (audioRecord === record) {
            audioRecord = null
        }
    }

    private fun configureAudioEffects(record: AudioRecord): AudioEffectsState {
        val audioSessionId = record.audioSessionId
        val aecAvailable = AcousticEchoCanceler.isAvailable()
        val noiseSuppressorAvailable = NoiseSuppressor.isAvailable()
        val agcAvailable = AutomaticGainControl.isAvailable()
        val aecEnabled = config.enableEchoCanceler &&
            aecAvailable &&
            enableAcousticEchoCanceler(audioSessionId)
        val noiseSuppressorEnabled = config.enableNoiseSuppressor &&
            noiseSuppressorAvailable &&
            enableNoiseSuppressor(audioSessionId)
        val agcEnabled = config.enableAutomaticGainControl &&
            agcAvailable &&
            enableAutomaticGainControl(audioSessionId)

        return AudioEffectsState(
            aecAvailable = aecAvailable,
            aecEnabled = aecEnabled,
            noiseSuppressorAvailable = noiseSuppressorAvailable,
            noiseSuppressorEnabled = noiseSuppressorEnabled,
            agcAvailable = agcAvailable,
            agcEnabled = agcEnabled,
        )
    }

    private fun emitAudioEffectStatuses(state: AudioEffectsState) {
        if (state.aecEnabled) {
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_ECHO_CANCELER_ENABLED,
                "AcousticEchoCanceler enabled for microphone capture.",
                state.fields(),
            )
        }
        if (state.noiseSuppressorEnabled) {
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_NOISE_SUPPRESSOR_ENABLED,
                "NoiseSuppressor enabled for microphone capture.",
                state.fields(),
            )
        }
        if (state.agcEnabled) {
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_AUTOMATIC_GAIN_CONTROL_ENABLED,
                "AutomaticGainControl enabled for microphone capture.",
                state.fields(),
            )
        }

        val requestedUnavailableOrFailed =
            (config.enableEchoCanceler && !state.aecEnabled) ||
                (config.enableNoiseSuppressor && !state.noiseSuppressorEnabled) ||
                (config.enableAutomaticGainControl && !state.agcEnabled)
        if (requestedUnavailableOrFailed) {
            listener.onMicrophoneCaptureStatus(
                LiveCaptureAudioContract.STATUS_MICROPHONE_ECHO_CONTROL_UNAVAILABLE,
                "One or more microphone echo-control effects were unavailable or could not be enabled.",
                state.fields(),
            )
        }
    }

    private fun enableAcousticEchoCanceler(audioSessionId: Int): Boolean {
        val effect = try {
            AcousticEchoCanceler.create(audioSessionId)
        } catch (_: RuntimeException) {
            null
        } ?: return false

        return try {
            effect.enabled = true
            acousticEchoCanceler = effect
            effect.enabled
        } catch (_: RuntimeException) {
            effect.release()
            false
        }
    }

    private fun enableNoiseSuppressor(audioSessionId: Int): Boolean {
        val effect = try {
            NoiseSuppressor.create(audioSessionId)
        } catch (_: RuntimeException) {
            null
        } ?: return false

        return try {
            effect.enabled = true
            noiseSuppressor = effect
            effect.enabled
        } catch (_: RuntimeException) {
            effect.release()
            false
        }
    }

    private fun enableAutomaticGainControl(audioSessionId: Int): Boolean {
        val effect = try {
            AutomaticGainControl.create(audioSessionId)
        } catch (_: RuntimeException) {
            null
        } ?: return false

        return try {
            effect.enabled = true
            automaticGainControl = effect
            effect.enabled
        } catch (_: RuntimeException) {
            effect.release()
            false
        }
    }

    private fun releaseAudioEffects() {
        try {
            acousticEchoCanceler?.release()
        } catch (_: RuntimeException) {
            // Best-effort effect release.
        }
        try {
            noiseSuppressor?.release()
        } catch (_: RuntimeException) {
            // Best-effort effect release.
        }
        try {
            automaticGainControl?.release()
        } catch (_: RuntimeException) {
            // Best-effort effect release.
        }
        acousticEchoCanceler = null
        noiseSuppressor = null
        automaticGainControl = null
    }

    private fun emitStoppedOnce() {
        if (stoppedEmitted.compareAndSet(false, true)) {
            listener.onMicrophoneCaptureStopped()
        }
    }

    private data class SelectedRecord(
        val audioRecord: AudioRecord,
        val sampleRateHz: Int,
        val channelCount: Int,
        val bufferSizeBytes: Int,
        val readBufferShorts: Int,
        val audioSourceName: String,
    )

    private data class AudioEffectsState(
        val aecAvailable: Boolean,
        val aecEnabled: Boolean,
        val noiseSuppressorAvailable: Boolean,
        val noiseSuppressorEnabled: Boolean,
        val agcAvailable: Boolean,
        val agcEnabled: Boolean,
    ) {
        fun fields(): Map<String, Any?> {
            return mapOf(
                "microphoneAecAvailable" to aecAvailable,
                "microphoneAecEnabled" to aecEnabled,
                "microphoneNoiseSuppressorAvailable" to noiseSuppressorAvailable,
                "microphoneNoiseSuppressorEnabled" to noiseSuppressorEnabled,
                "microphoneAgcAvailable" to agcAvailable,
                "microphoneAgcEnabled" to agcEnabled,
            )
        }
    }

    private object CaptureThreadFactory : ThreadFactory {
        override fun newThread(runnable: Runnable): Thread {
            return Thread(runnable, "WrapUpMicrophoneCapture").apply {
                isDaemon = true
            }
        }
    }
}
