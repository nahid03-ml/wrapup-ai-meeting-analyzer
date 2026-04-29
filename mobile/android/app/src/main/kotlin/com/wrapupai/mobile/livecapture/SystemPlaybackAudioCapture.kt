package com.wrapupai.mobile.livecapture

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioPlaybackCaptureConfiguration
import android.media.AudioRecord
import android.media.projection.MediaProjection
import android.os.Build
import android.os.SystemClock
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicBoolean

class SystemPlaybackAudioCapture(
    private val mediaProjection: MediaProjection,
    private val config: LiveCaptureConfig,
    private val listener: Listener,
) {
    interface Listener {
        fun onPlaybackCaptureStarting()
        fun onPlaybackCaptureStarted(sampleRateHz: Int)
        fun onPlaybackAudioLevel(level: Double, isSilent: Boolean, sampleRateHz: Int)
        fun onPlaybackCaptureStatus(
            status: String,
            message: String? = null,
            fields: Map<String, Any?> = emptyMap(),
        )
        fun onPlaybackCaptureWarning(message: String, code: String? = null)
        fun onPlaybackCaptureError(code: String, message: String)
        fun onPlaybackCaptureStopped()
    }

    private val running = AtomicBoolean(false)
    private val stoppedEmitted = AtomicBoolean(false)
    private val released = AtomicBoolean(false)
    private val levelMeter = AudioLevelMeter()

    @Volatile
    private var audioRecord: AudioRecord? = null

    @Volatile
    private var executor: ExecutorService? = null

    fun start() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            listener.onPlaybackCaptureError(
                LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_UNSUPPORTED,
                "Android playback capture requires Android 10 or newer.",
            )
            return
        }

        if (!running.compareAndSet(false, true)) {
            return
        }
        stoppedEmitted.set(false)
        released.set(false)

        listener.onPlaybackCaptureStarting()

        val playbackConfig = AudioPlaybackCaptureConfiguration.Builder(mediaProjection)
            .addMatchingUsage(AudioAttributes.USAGE_MEDIA)
            .addMatchingUsage(AudioAttributes.USAGE_GAME)
            .addMatchingUsage(AudioAttributes.USAGE_UNKNOWN)
            .build()

        val selectedFormat = selectFormat()
        if (selectedFormat == null) {
            running.set(false)
            listener.onPlaybackCaptureError(
                LiveCaptureAudioContract.ERROR_AUDIO_RECORD_INIT_FAILED,
                "AudioRecord could not find a supported playback capture format.",
            )
            return
        }

        val record = try {
            AudioRecord.Builder()
                .setAudioPlaybackCaptureConfig(playbackConfig)
                .setAudioFormat(selectedFormat.audioFormat)
                .setBufferSizeInBytes(selectedFormat.bufferSizeBytes)
                .build()
        } catch (error: SecurityException) {
            running.set(false)
            listener.onPlaybackCaptureError(
                LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_SECURITY,
                error.message ?: "Playback capture permission was rejected.",
            )
            return
        } catch (error: RuntimeException) {
            running.set(false)
            listener.onPlaybackCaptureError(
                LiveCaptureAudioContract.ERROR_AUDIO_RECORD_INIT_FAILED,
                error.message ?: "AudioRecord could not be initialized.",
            )
            return
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            running.set(false)
            record.release()
            released.set(true)
            listener.onPlaybackCaptureError(
                LiveCaptureAudioContract.ERROR_AUDIO_RECORD_INIT_FAILED,
                "AudioRecord initialized in an invalid state.",
            )
            emitStoppedOnce()
            return
        }

        audioRecord = record
        listener.onPlaybackCaptureStatus(
            LiveCaptureAudioContract.STATUS_AUDIO_RECORD_BUILT,
            "Playback AudioRecord was built.",
            mapOf(
                "sampleRateHz" to selectedFormat.sampleRateHz,
                "channelCount" to selectedFormat.channelCount,
                "bufferSizeBytes" to selectedFormat.bufferSizeBytes,
                "recordingState" to record.recordingState,
            ),
        )
        executor = Executors.newSingleThreadExecutor(CaptureThreadFactory)
        executor?.execute {
            readLoop(
                record = record,
                sampleRateHz = selectedFormat.sampleRateHz,
                channelCount = selectedFormat.channelCount,
                bufferSizeBytes = selectedFormat.bufferSizeBytes,
                readBufferShorts = selectedFormat.readBufferShorts,
            )
        }
    }

    fun stop() {
        listener.onPlaybackCaptureStatus(
            LiveCaptureAudioContract.STATUS_PLAYBACK_CAPTURE_STOP_REQUESTED,
            "Stopping Android system playback capture.",
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

    private fun selectFormat(): SelectedFormat? {
        val sampleRates = listOf(
            config.sampleRateHz,
            LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
            48000,
            44100,
        ).distinct().filter { it > 0 }

        val channelOptions = listOf(
            AudioFormat.CHANNEL_IN_MONO to 1,
            AudioFormat.CHANNEL_IN_STEREO to 2,
        )

        for (sampleRateHz in sampleRates) {
            for ((channelMask, channelCount) in channelOptions) {
                val minBufferSize = AudioRecord.getMinBufferSize(
                    sampleRateHz,
                    channelMask,
                    AudioFormat.ENCODING_PCM_16BIT,
                )
                if (minBufferSize <= 0) {
                    continue
                }

                val readBufferShorts = maxOf((sampleRateHz / 20) * channelCount, 320)
                val requestedBufferBytes = maxOf(
                    minBufferSize * 2,
                    readBufferShorts * LiveCaptureAudioContract.BYTES_PER_SAMPLE,
                )
                val audioFormat = AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRateHz)
                    .setChannelMask(channelMask)
                    .build()
                return SelectedFormat(
                    sampleRateHz = sampleRateHz,
                    channelCount = channelCount,
                    bufferSizeBytes = requestedBufferBytes,
                    readBufferShorts = requestedBufferBytes /
                        LiveCaptureAudioContract.BYTES_PER_SAMPLE,
                    audioFormat = audioFormat,
                )
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
                listener.onPlaybackCaptureStatus(
                    LiveCaptureAudioContract.STATUS_AUDIO_RECORD_START_REQUESTED,
                    "Starting playback AudioRecord.",
                    mapOf(
                        "sampleRateHz" to sampleRateHz,
                        "channelCount" to channelCount,
                        "bufferSizeBytes" to bufferSizeBytes,
                        "recordingState" to record.recordingState,
                    ),
                )
                record.startRecording()
            } catch (error: SecurityException) {
                running.set(false)
                listener.onPlaybackCaptureError(
                    LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_SECURITY,
                    error.message ?: "AudioRecord start was rejected.",
                )
                return
            } catch (error: IllegalStateException) {
                running.set(false)
                listener.onPlaybackCaptureError(
                    LiveCaptureAudioContract.ERROR_AUDIO_RECORD_START_FAILED,
                    error.message ?: "AudioRecord could not start recording.",
                )
                return
            }

            if (record.recordingState != AudioRecord.RECORDSTATE_RECORDING) {
                running.set(false)
                listener.onPlaybackCaptureError(
                    LiveCaptureAudioContract.ERROR_AUDIO_RECORD_START_FAILED,
                    "AudioRecord did not enter recording state. recordingState=${record.recordingState}",
                )
                return
            }

            listener.onPlaybackCaptureStatus(
                LiveCaptureAudioContract.STATUS_AUDIO_RECORD_RECORDING,
                "Playback AudioRecord entered recording state.",
                mapOf("recordingState" to record.recordingState),
            )
            listener.onPlaybackCaptureStarted(sampleRateHz)
            readStartedAtMs = SystemClock.elapsedRealtime()
            listener.onPlaybackCaptureStatus(
                LiveCaptureAudioContract.STATUS_PLAYBACK_READ_STARTED,
                "Playback capture read loop started.",
                mapOf("recordingState" to record.recordingState),
            )

            while (running.get()) {
                val read = try {
                    record.read(buffer, 0, buffer.size, AudioRecord.READ_NON_BLOCKING)
                } catch (error: IllegalStateException) {
                    if (running.get()) {
                        listener.onPlaybackCaptureError(
                            LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_READ_FAILED,
                            error.message ?: "AudioRecord read failed.",
                        )
                    }
                    break
                }
                val nowMs = SystemClock.elapsedRealtime()
                if (read > 0) {
                    if (firstFrameReadAtMs == 0L) {
                        firstFrameReadAtMs = nowMs
                        listener.onPlaybackCaptureStatus(
                            LiveCaptureAudioContract.STATUS_PLAYBACK_FIRST_FRAME_READ,
                            "First playback audio frame was read.",
                            mapOf(
                                "readResult" to read,
                                "recordingState" to record.recordingState,
                                "sampleRateHz" to sampleRateHz,
                            ),
                        )
                    }

                    val level = levelMeter.calculate(buffer, read)
                    if (!level.isSilent) {
                        lastNonSilentAtMs = nowMs
                        if (!audioDetectedEmitted || silentWarningEmitted) {
                            listener.onPlaybackCaptureStatus(
                                LiveCaptureAudioContract.STATUS_DEVICE_AUDIO_DETECTED,
                                "Device audio detected.",
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
                        listener.onPlaybackCaptureWarning(
                            "No device audio detected. The current app may be silent or may block playback capture.",
                            LiveCaptureAudioContract.WARNING_SYSTEM_PLAYBACK_SILENT,
                        )
                    }

                    if (nowMs - lastLevelEventAtMs >= LiveCaptureAudioContract.LEVEL_EMIT_INTERVAL_MS) {
                        lastLevelEventAtMs = nowMs
                        listener.onPlaybackAudioLevel(
                            level = level.level,
                            isSilent = level.isSilent,
                            sampleRateHz = sampleRateHz,
                        )
                    }
                } else if (read == 0) {
                    if (
                        nowMs - lastNoDataEventAtMs >=
                        LiveCaptureAudioContract.NO_DATA_STATUS_INTERVAL_MS
                    ) {
                        lastNoDataEventAtMs = nowMs
                        listener.onPlaybackCaptureStatus(
                            LiveCaptureAudioContract.STATUS_PLAYBACK_READ_NO_DATA,
                            "Playback capture read returned no data yet.",
                            mapOf(
                                "readResult" to read,
                                "recordingState" to record.recordingState,
                            ),
                        )
                    }
                    if (
                        !noFrameWarningEmitted &&
                        firstFrameReadAtMs == 0L &&
                        nowMs - readStartedAtMs >= LiveCaptureAudioContract.NO_FRAME_WARNING_MS
                    ) {
                        noFrameWarningEmitted = true
                        listener.onPlaybackCaptureWarning(
                            "Playback capture started but no audio frames were read. The emulator/app may not expose capturable playback audio.",
                            LiveCaptureAudioContract.WARNING_PLAYBACK_CAPTURE_NO_FRAMES,
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
                        listener.onPlaybackCaptureError(
                            LiveCaptureAudioContract.ERROR_PLAYBACK_CAPTURE_READ_FAILED,
                            "AudioRecord read failed with code $read.",
                        )
                    }
                    break
                }
            }
        } finally {
            running.set(false)
            listener.onPlaybackCaptureStatus(
                LiveCaptureAudioContract.STATUS_PLAYBACK_READ_STOPPED,
                "Playback capture read loop stopped.",
            )
            releaseRecord(record)
            emitStoppedOnce()
        }
    }

    private fun releaseRecord(record: AudioRecord?) {
        if (record == null || !released.compareAndSet(false, true)) {
            return
        }
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

    private fun emitStoppedOnce() {
        if (stoppedEmitted.compareAndSet(false, true)) {
            listener.onPlaybackCaptureStopped()
        }
    }

    private data class SelectedFormat(
        val sampleRateHz: Int,
        val channelCount: Int,
        val bufferSizeBytes: Int,
        val readBufferShorts: Int,
        val audioFormat: AudioFormat,
    )

    private object CaptureThreadFactory : ThreadFactory {
        override fun newThread(runnable: Runnable): Thread {
            return Thread(runnable, "WrapUpSystemPlaybackCapture").apply {
                isDaemon = true
            }
        }
    }
}
