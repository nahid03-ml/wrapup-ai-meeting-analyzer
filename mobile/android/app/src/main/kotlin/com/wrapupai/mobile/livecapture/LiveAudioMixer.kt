package com.wrapupai.mobile.livecapture

import android.os.SystemClock
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.roundToInt

class LiveAudioMixer(
    private val config: LiveCaptureConfig,
    private val listener: Listener,
) {
    interface Listener {
        fun onMixedCaptureStatus(
            status: String,
            message: String? = null,
            fields: Map<String, Any?> = emptyMap(),
        )

        fun onMixedAudioLevel(
            level: Double,
            isSilent: Boolean,
            clippingCount: Int,
            systemFramesBuffered: Int,
            micFramesBuffered: Int,
            micDucked: Boolean,
            effectiveMicGain: Double,
            effectiveSystemGain: Double,
        )

        fun onMixedPcmFrame(frame: MixedAudioFrame)
        fun onMixedCaptureWarning(message: String, code: String? = null)
        fun onMixedCaptureStopped()
    }

    private val running = AtomicBoolean(false)
    private val stoppedEmitted = AtomicBoolean(false)
    private val resampler = PcmResampler()
    private val systemBuffer = PcmFrameBuffer()
    private val microphoneBuffer = PcmFrameBuffer()
    private val levelMeter = AudioLevelMeter()

    @Volatile
    private var executor: ExecutorService? = null

    @Volatile
    private var lastDropWarningAtMs = 0L

    fun start() {
        if (!running.compareAndSet(false, true)) {
            return
        }
        stoppedEmitted.set(false)
        listener.onMixedCaptureStatus(
            LiveCaptureAudioContract.STATUS_MIXED_CAPTURE_STARTING,
            "Starting local native mic and system audio mixer.",
        )
        executor = Executors.newSingleThreadExecutor(MixerThreadFactory)
        executor?.execute(::mixLoop)
        listener.onMixedCaptureStatus(
            LiveCaptureAudioContract.STATUS_MIXED_CAPTURE_STARTED,
            "Local native mixer started at ${LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ} Hz mono.",
            baseFields(),
        )
    }

    fun acceptSystemFrame(
        samples: ShortArray,
        sampleCount: Int,
        sampleRateHz: Int,
        channelCount: Int,
    ) {
        if (!running.get()) {
            return
        }
        val normalized = resampler.toTargetMono(
            samples = samples,
            sampleCount = sampleCount,
            sampleRateHz = sampleRateHz,
            channelCount = channelCount,
        )
        if (normalized.isEmpty()) {
            return
        }
        emitFrameDropIfNeeded(systemBuffer.offer(normalized))
    }

    fun acceptMicrophoneFrame(
        samples: ShortArray,
        sampleCount: Int,
        sampleRateHz: Int,
        channelCount: Int,
        audioSourceName: String,
    ) {
        if (!running.get()) {
            return
        }
        val normalized = resampler.toTargetMono(
            samples = samples,
            sampleCount = sampleCount,
            sampleRateHz = sampleRateHz,
            channelCount = channelCount,
        )
        if (normalized.isEmpty()) {
            return
        }
        emitFrameDropIfNeeded(
            microphoneBuffer.offer(normalized),
            mapOf("audioSource" to audioSourceName),
        )
    }

    fun stop() {
        running.set(false)
        systemBuffer.clear()
        microphoneBuffer.clear()
        executor?.shutdownNow()
        listener.onMixedCaptureStatus(
            LiveCaptureAudioContract.STATUS_MIXED_CAPTURE_STOPPED,
            "Local native mixer stopped.",
            baseFields(),
        )
        emitStoppedOnce()
    }

    private fun mixLoop() {
        var lastLevelEventAtMs = 0L
        var lastNoInputStatusAtMs = 0L
        var firstOutputAtMs = 0L
        var lastNonSilentAtMs = 0L
        var lastOutputStatusAtMs = 0L
        var lastClippingWarningAtMs = 0L
        var clippingSinceWarning = 0
        var totalClippingCount = 0
        var silentWarningEmitted = false
        var audioDetectedEmitted = false
        var onlySystemWarningEmitted = false
        var onlyMicWarningEmitted = false
        var micDuckedForEchoControl = false
        val startedAtMs = SystemClock.elapsedRealtime()

        listener.onMixedCaptureStatus(
            LiveCaptureAudioContract.STATUS_MIXED_READ_STARTED,
            "Local native mixer loop started.",
            baseFields(),
        )

        try {
            while (running.get()) {
                val systemFrame = systemBuffer.poll()
                val microphoneFrame = microphoneBuffer.poll()
                val nowMs = SystemClock.elapsedRealtime()

                if (systemFrame == null && microphoneFrame == null) {
                    if (
                        nowMs - lastNoInputStatusAtMs >=
                        LiveCaptureAudioContract.NO_DATA_STATUS_INTERVAL_MS
                    ) {
                        lastNoInputStatusAtMs = nowMs
                        listener.onMixedCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MIXED_AUDIO_NO_INPUT,
                            "Mixer is waiting for system or microphone frames.",
                            fields(),
                        )
                    }
                    sleepBriefly()
                    continue
                }

                if (
                    systemFrame != null &&
                    microphoneFrame == null &&
                    !onlySystemWarningEmitted &&
                    nowMs - startedAtMs >= LiveCaptureAudioContract.SILENCE_WARNING_MS
                ) {
                    onlySystemWarningEmitted = true
                    listener.onMixedCaptureWarning(
                        "Mixed audio is currently receiving only system playback frames.",
                        LiveCaptureAudioContract.WARNING_MIXED_AUDIO_ONLY_SYSTEM_ACTIVE,
                    )
                }
                if (
                    systemFrame == null &&
                    microphoneFrame != null &&
                    !onlyMicWarningEmitted &&
                    nowMs - startedAtMs >= LiveCaptureAudioContract.SILENCE_WARNING_MS
                ) {
                    onlyMicWarningEmitted = true
                    listener.onMixedCaptureWarning(
                        "Mixed audio is currently receiving only microphone frames.",
                        LiveCaptureAudioContract.WARNING_MIXED_AUDIO_ONLY_MICROPHONE_ACTIVE,
                    )
                }

                val systemLevel = sourceLevel(systemFrame)
                val microphoneLevel = sourceLevel(microphoneFrame)
                val shouldDuckMic = shouldDuckMicrophone(
                    systemLevel = systemLevel,
                    microphoneLevel = microphoneLevel,
                )
                if (shouldDuckMic != micDuckedForEchoControl) {
                    micDuckedForEchoControl = shouldDuckMic
                    if (micDuckedForEchoControl) {
                        listener.onMixedCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MIXED_MIC_DUCKED_FOR_ECHO_CONTROL,
                            "Microphone gain reduced while system audio is active.",
                            fields(
                                micDucked = true,
                                effectiveMicGain = config.micEchoDuckedGain,
                                effectiveSystemGain = config.systemGain,
                            ),
                        )
                    } else {
                        listener.onMixedCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MIXED_MIC_RESTORED_AFTER_ECHO_CONTROL,
                            "Microphone gain restored for stronger voice input.",
                            fields(
                                micDucked = false,
                                effectiveMicGain = config.micGain,
                                effectiveSystemGain = config.systemGain,
                            ),
                        )
                    }
                }

                val effectiveMicGain = if (micDuckedForEchoControl) {
                    config.micEchoDuckedGain
                } else {
                    config.micGain
                }
                val effectiveSystemGain = config.systemGain

                val mixedFrame = mixFrames(
                    systemFrame = systemFrame,
                    microphoneFrame = microphoneFrame,
                    effectiveSystemGain = effectiveSystemGain,
                    effectiveMicGain = effectiveMicGain,
                )
                if (mixedFrame.samples.isEmpty()) {
                    sleepBriefly()
                    continue
                }

                if (
                    firstOutputAtMs == 0L ||
                    nowMs - lastOutputStatusAtMs >=
                    LiveCaptureAudioContract.NO_DATA_STATUS_INTERVAL_MS
                ) {
                    lastOutputStatusAtMs = nowMs
                    listener.onMixedCaptureStatus(
                        LiveCaptureAudioContract.STATUS_MIXED_OUTPUT_FRAME_READY,
                        "Mixed PCM output frame is ready.",
                        fields(
                            clippingCount = mixedFrame.clippingCount,
                            micDucked = micDuckedForEchoControl,
                            effectiveMicGain = effectiveMicGain,
                            effectiveSystemGain = effectiveSystemGain,
                        ),
                    )
                }
                if (firstOutputAtMs == 0L) {
                    firstOutputAtMs = nowMs
                }

                val level = levelMeter.calculate(mixedFrame.samples, mixedFrame.samples.size)
                listener.onMixedPcmFrame(mixedFrame)

                if (!level.isSilent) {
                    lastNonSilentAtMs = nowMs
                    if (!audioDetectedEmitted || silentWarningEmitted) {
                        listener.onMixedCaptureStatus(
                            LiveCaptureAudioContract.STATUS_MIXED_AUDIO_DETECTED,
                            "Mixed audio detected.",
                            fields(
                                clippingCount = mixedFrame.clippingCount,
                                micDucked = micDuckedForEchoControl,
                                effectiveMicGain = effectiveMicGain,
                                effectiveSystemGain = effectiveSystemGain,
                            ),
                        )
                    }
                    audioDetectedEmitted = true
                    silentWarningEmitted = false
                }

                if (
                    !silentWarningEmitted &&
                    level.isSilent &&
                    firstOutputAtMs > 0L &&
                    nowMs - firstOutputAtMs >= LiveCaptureAudioContract.SILENCE_WARNING_MS &&
                    (lastNonSilentAtMs == 0L ||
                        nowMs - lastNonSilentAtMs >=
                        LiveCaptureAudioContract.SILENCE_WARNING_MS)
                ) {
                    silentWarningEmitted = true
                    listener.onMixedCaptureWarning(
                        "Mixed audio is silent. Check system playback and microphone input.",
                        LiveCaptureAudioContract.WARNING_MIXED_AUDIO_SILENT,
                    )
                }

                if (mixedFrame.clippingCount > 0) {
                    totalClippingCount += mixedFrame.clippingCount
                    clippingSinceWarning += mixedFrame.clippingCount
                    if (
                        clippingSinceWarning >= 5 &&
                        nowMs - lastClippingWarningAtMs >= 2000L
                    ) {
                        lastClippingWarningAtMs = nowMs
                        clippingSinceWarning = 0
                        listener.onMixedCaptureWarning(
                            "Mixed audio clipped and was clamped to prevent overflow.",
                            LiveCaptureAudioContract.WARNING_MIXED_AUDIO_CLIPPING,
                        )
                    }
                }

                if (nowMs - lastLevelEventAtMs >= LiveCaptureAudioContract.LEVEL_EMIT_INTERVAL_MS) {
                    lastLevelEventAtMs = nowMs
                    listener.onMixedAudioLevel(
                        level = level.level,
                        isSilent = level.isSilent,
                        clippingCount = totalClippingCount,
                        systemFramesBuffered = systemBuffer.size(),
                        micFramesBuffered = microphoneBuffer.size(),
                        micDucked = micDuckedForEchoControl,
                        effectiveMicGain = effectiveMicGain,
                        effectiveSystemGain = effectiveSystemGain,
                    )
                }

                sleepBriefly()
            }
        } finally {
            systemBuffer.clear()
            microphoneBuffer.clear()
            listener.onMixedCaptureStatus(
                LiveCaptureAudioContract.STATUS_MIXED_CAPTURE_STOPPED,
                "Local native mixer loop stopped.",
                baseFields(),
            )
            emitStoppedOnce()
        }
    }

    private fun mixFrames(
        systemFrame: ShortArray?,
        microphoneFrame: ShortArray?,
        effectiveSystemGain: Double,
        effectiveMicGain: Double,
    ): MixedAudioFrame {
        val outputLength = maxOf(systemFrame?.size ?: 0, microphoneFrame?.size ?: 0)
        if (outputLength <= 0) {
            return MixedAudioFrame(samples = ShortArray(0))
        }

        val mixed = ShortArray(outputLength)
        var clippingCount = 0
        for (index in 0 until outputLength) {
            val systemSample = systemFrame.sampleAt(index) * effectiveSystemGain
            val microphoneSample = microphoneFrame.sampleAt(index) * effectiveMicGain
            val summed = systemSample + microphoneSample
            if (abs(summed) > 1.0) {
                clippingCount += 1
            }
            mixed[index] = (summed.coerceIn(-1.0, 1.0) * Short.MAX_VALUE.toDouble())
                .roundToInt()
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                .toShort()
        }

        return MixedAudioFrame(samples = mixed, clippingCount = clippingCount)
    }

    private fun ShortArray?.sampleAt(index: Int): Double {
        if (this == null || index !in indices) {
            return 0.0
        }
        return this[index].toDouble() / Short.MAX_VALUE.toDouble()
    }

    private fun sourceLevel(frame: ShortArray?): Double {
        if (frame == null || frame.isEmpty()) {
            return 0.0
        }
        return levelMeter.calculate(frame, frame.size).level
    }

    private fun shouldDuckMicrophone(systemLevel: Double, microphoneLevel: Double): Boolean {
        return config.enableMicDucking &&
            systemLevel >= config.systemActiveThreshold &&
            microphoneLevel < config.micSpeechThreshold
    }

    private fun emitFrameDropIfNeeded(
        droppedFrames: Int,
        fields: Map<String, Any?> = emptyMap(),
    ) {
        if (droppedFrames <= 0) {
            return
        }
        val nowMs = SystemClock.elapsedRealtime()
        if (nowMs - lastDropWarningAtMs < LiveCaptureAudioContract.NO_DATA_STATUS_INTERVAL_MS) {
            return
        }
        lastDropWarningAtMs = nowMs
        listener.onMixedCaptureWarning(
            "Mixed audio frame buffer dropped old frames to stay bounded.",
            LiveCaptureAudioContract.WARNING_MIXED_AUDIO_FRAME_DROP,
        )
        listener.onMixedCaptureStatus(
            LiveCaptureAudioContract.STATUS_MIXED_OUTPUT_FRAME_READY,
            "Mixed audio frame buffer dropped old frames to stay bounded.",
            fields(droppedFrames = droppedFrames) + fields,
        )
    }

    private fun fields(
        clippingCount: Int = 0,
        droppedFrames: Int = 0,
        micDucked: Boolean = false,
        effectiveMicGain: Double = config.micGain,
        effectiveSystemGain: Double = config.systemGain,
    ): Map<String, Any?> {
        return baseFields() + mapOf(
            "clippingCount" to clippingCount,
            "systemFramesBuffered" to systemBuffer.size(),
            "micFramesBuffered" to microphoneBuffer.size(),
            "droppedFrames" to droppedFrames,
            "micDucked" to micDucked,
            "effectiveMicGain" to effectiveMicGain,
            "effectiveSystemGain" to effectiveSystemGain,
        )
    }

    private fun baseFields(): Map<String, Any?> {
        return mapOf(
            "sampleRateHz" to LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
            "channelCount" to LiveCaptureAudioContract.CHANNEL_COUNT,
        )
    }

    private fun sleepBriefly() {
        try {
            Thread.sleep(MIX_INTERVAL_MS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
        }
    }

    private fun emitStoppedOnce() {
        if (stoppedEmitted.compareAndSet(false, true)) {
            listener.onMixedCaptureStopped()
        }
    }

    private object MixerThreadFactory : ThreadFactory {
        override fun newThread(runnable: Runnable): Thread {
            return Thread(runnable, "WrapUpLiveAudioMixer").apply {
                isDaemon = true
            }
        }
    }

    companion object {
        private const val MIX_INTERVAL_MS = 20L
    }
}
