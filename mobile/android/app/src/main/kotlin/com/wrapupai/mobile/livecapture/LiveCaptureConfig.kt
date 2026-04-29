package com.wrapupai.mobile.livecapture

import android.content.Intent

data class LiveCaptureConfig(
    val captureSystemAudio: Boolean = true,
    val captureMicrophone: Boolean = true,
    val sampleRateHz: Int = 16000,
    val channelCount: Int = 1,
    val bitsPerSample: Int = 16,
    val micGain: Double = 0.8,
    val systemGain: Double = 0.8,
) {
    fun addToIntent(intent: Intent): Intent {
        return intent
            .putExtra(EXTRA_CAPTURE_SYSTEM_AUDIO, captureSystemAudio)
            .putExtra(EXTRA_CAPTURE_MICROPHONE, captureMicrophone)
            .putExtra(EXTRA_SAMPLE_RATE_HZ, sampleRateHz)
            .putExtra(EXTRA_CHANNEL_COUNT, channelCount)
            .putExtra(EXTRA_BITS_PER_SAMPLE, bitsPerSample)
            .putExtra(EXTRA_MIC_GAIN, micGain)
            .putExtra(EXTRA_SYSTEM_GAIN, systemGain)
    }

    companion object {
        const val EXTRA_CAPTURE_SYSTEM_AUDIO = "captureSystemAudio"
        const val EXTRA_CAPTURE_MICROPHONE = "captureMicrophone"
        const val EXTRA_SAMPLE_RATE_HZ = "sampleRateHz"
        const val EXTRA_CHANNEL_COUNT = "channelCount"
        const val EXTRA_BITS_PER_SAMPLE = "bitsPerSample"
        const val EXTRA_MIC_GAIN = "micGain"
        const val EXTRA_SYSTEM_GAIN = "systemGain"

        fun fromArguments(arguments: Any?): LiveCaptureConfig {
            val map = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
            return LiveCaptureConfig(
                captureSystemAudio = map.booleanValue("captureSystemAudio", true),
                captureMicrophone = map.booleanValue("captureMicrophone", true),
                sampleRateHz = map.intValue("sampleRateHz", 16000),
                channelCount = map.intValue("channelCount", 1),
                bitsPerSample = map.intValue("bitsPerSample", 16),
                micGain = map.doubleValue("micGain", 0.8),
                systemGain = map.doubleValue("systemGain", 0.8),
            )
        }

        fun fromIntent(intent: Intent): LiveCaptureConfig {
            return LiveCaptureConfig(
                captureSystemAudio = intent.getBooleanExtra(EXTRA_CAPTURE_SYSTEM_AUDIO, true),
                captureMicrophone = intent.getBooleanExtra(EXTRA_CAPTURE_MICROPHONE, true),
                sampleRateHz = intent.getIntExtra(EXTRA_SAMPLE_RATE_HZ, 16000),
                channelCount = intent.getIntExtra(EXTRA_CHANNEL_COUNT, 1),
                bitsPerSample = intent.getIntExtra(EXTRA_BITS_PER_SAMPLE, 16),
                micGain = intent.getDoubleExtra(EXTRA_MIC_GAIN, 0.8),
                systemGain = intent.getDoubleExtra(EXTRA_SYSTEM_GAIN, 0.8),
            )
        }
    }
}

private fun Map<*, *>.booleanValue(key: String, defaultValue: Boolean): Boolean {
    return when (val value = this[key]) {
        is Boolean -> value
        is String -> value.toBooleanStrictOrNull() ?: defaultValue
        else -> defaultValue
    }
}

private fun Map<*, *>.intValue(key: String, defaultValue: Int): Int {
    return when (val value = this[key]) {
        is Int -> value
        is Number -> value.toInt()
        is String -> value.toIntOrNull() ?: defaultValue
        else -> defaultValue
    }
}

private fun Map<*, *>.doubleValue(key: String, defaultValue: Double): Double {
    return when (val value = this[key]) {
        is Number -> value.toDouble()
        is String -> value.toDoubleOrNull() ?: defaultValue
        else -> defaultValue
    }
}
