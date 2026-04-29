package com.wrapupai.mobile.livecapture

import kotlin.math.sqrt

data class AudioLevelResult(
    val level: Double,
    val isSilent: Boolean,
)

class AudioLevelMeter(
    private val silenceThreshold: Double = LiveCaptureAudioContract.SILENCE_LEVEL_THRESHOLD,
) {
    fun calculate(samples: ShortArray, sampleCount: Int): AudioLevelResult {
        if (sampleCount <= 0) {
            return AudioLevelResult(level = 0.0, isSilent = true)
        }

        var sumSquares = 0.0
        for (index in 0 until sampleCount) {
            val normalized = samples[index].toDouble() / Short.MAX_VALUE.toDouble()
            sumSquares += normalized * normalized
        }

        val rms = sqrt(sumSquares / sampleCount.toDouble()).coerceIn(0.0, 1.0)
        return AudioLevelResult(level = rms, isSilent = rms < silenceThreshold)
    }
}
