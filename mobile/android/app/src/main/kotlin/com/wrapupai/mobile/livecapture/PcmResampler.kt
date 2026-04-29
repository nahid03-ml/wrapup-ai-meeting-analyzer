package com.wrapupai.mobile.livecapture

import kotlin.math.floor
import kotlin.math.roundToInt

class PcmResampler(
    private val targetSampleRateHz: Int = LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
) {
    fun toTargetMono(
        samples: ShortArray,
        sampleCount: Int,
        sampleRateHz: Int,
        channelCount: Int,
    ): ShortArray {
        if (sampleCount <= 0 || sampleRateHz <= 0 || channelCount <= 0) {
            return ShortArray(0)
        }

        val mono = downmixToMono(samples, sampleCount, channelCount)
        if (sampleRateHz == targetSampleRateHz) {
            return mono
        }
        if (mono.isEmpty()) {
            return mono
        }

        val outputLength = maxOf(
            1,
            (mono.size.toDouble() * targetSampleRateHz.toDouble() / sampleRateHz.toDouble())
                .roundToInt(),
        )
        if (outputLength == mono.size) {
            return mono
        }
        if (mono.size == 1) {
            return ShortArray(outputLength) { mono[0] }
        }

        val output = ShortArray(outputLength)
        for (index in output.indices) {
            val sourcePosition = index.toDouble() * sampleRateHz.toDouble() /
                targetSampleRateHz.toDouble()
            val lowerIndex = floor(sourcePosition).toInt().coerceIn(0, mono.lastIndex)
            val upperIndex = (lowerIndex + 1).coerceAtMost(mono.lastIndex)
            val fraction = (sourcePosition - lowerIndex.toDouble()).coerceIn(0.0, 1.0)
            val lower = mono[lowerIndex].toDouble()
            val upper = mono[upperIndex].toDouble()
            output[index] = (lower + ((upper - lower) * fraction))
                .roundToInt()
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                .toShort()
        }
        return output
    }

    private fun downmixToMono(
        samples: ShortArray,
        sampleCount: Int,
        channelCount: Int,
    ): ShortArray {
        val safeSampleCount = sampleCount.coerceAtMost(samples.size)
        val frameCount = safeSampleCount / channelCount
        if (frameCount <= 0) {
            return ShortArray(0)
        }
        if (channelCount == 1) {
            return samples.copyOf(frameCount)
        }

        val output = ShortArray(frameCount)
        for (frameIndex in 0 until frameCount) {
            var total = 0
            val baseIndex = frameIndex * channelCount
            for (channelIndex in 0 until channelCount) {
                total += samples[baseIndex + channelIndex].toInt()
            }
            output[frameIndex] = (total / channelCount)
                .coerceIn(Short.MIN_VALUE.toInt(), Short.MAX_VALUE.toInt())
                .toShort()
        }
        return output
    }
}
