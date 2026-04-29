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
    val enableEchoCanceler: Boolean = true,
    val enableNoiseSuppressor: Boolean = true,
    val enableAutomaticGainControl: Boolean = false,
    val enableMicDucking: Boolean = true,
    val micEchoDuckedGain: Double = 0.25,
    val systemActiveThreshold: Double = 0.02,
    val micSpeechThreshold: Double = 0.04,
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
            .putExtra(EXTRA_ENABLE_ECHO_CANCELER, enableEchoCanceler)
            .putExtra(EXTRA_ENABLE_NOISE_SUPPRESSOR, enableNoiseSuppressor)
            .putExtra(EXTRA_ENABLE_AUTOMATIC_GAIN_CONTROL, enableAutomaticGainControl)
            .putExtra(EXTRA_ENABLE_MIC_DUCKING, enableMicDucking)
            .putExtra(EXTRA_MIC_ECHO_DUCKED_GAIN, micEchoDuckedGain)
            .putExtra(EXTRA_SYSTEM_ACTIVE_THRESHOLD, systemActiveThreshold)
            .putExtra(EXTRA_MIC_SPEECH_THRESHOLD, micSpeechThreshold)
    }

    companion object {
        const val EXTRA_CAPTURE_SYSTEM_AUDIO = "captureSystemAudio"
        const val EXTRA_CAPTURE_MICROPHONE = "captureMicrophone"
        const val EXTRA_SAMPLE_RATE_HZ = "sampleRateHz"
        const val EXTRA_CHANNEL_COUNT = "channelCount"
        const val EXTRA_BITS_PER_SAMPLE = "bitsPerSample"
        const val EXTRA_MIC_GAIN = "micGain"
        const val EXTRA_SYSTEM_GAIN = "systemGain"
        const val EXTRA_ENABLE_ECHO_CANCELER = "enableEchoCanceler"
        const val EXTRA_ENABLE_NOISE_SUPPRESSOR = "enableNoiseSuppressor"
        const val EXTRA_ENABLE_AUTOMATIC_GAIN_CONTROL = "enableAutomaticGainControl"
        const val EXTRA_ENABLE_MIC_DUCKING = "enableMicDucking"
        const val EXTRA_MIC_ECHO_DUCKED_GAIN = "micEchoDuckedGain"
        const val EXTRA_SYSTEM_ACTIVE_THRESHOLD = "systemActiveThreshold"
        const val EXTRA_MIC_SPEECH_THRESHOLD = "micSpeechThreshold"

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
                enableEchoCanceler = map.booleanValue("enableEchoCanceler", true),
                enableNoiseSuppressor = map.booleanValue("enableNoiseSuppressor", true),
                enableAutomaticGainControl =
                    map.booleanValue("enableAutomaticGainControl", false),
                enableMicDucking = map.booleanValue("enableMicDucking", true),
                micEchoDuckedGain = map.doubleValue("micEchoDuckedGain", 0.25),
                systemActiveThreshold = map.doubleValue("systemActiveThreshold", 0.02),
                micSpeechThreshold = map.doubleValue("micSpeechThreshold", 0.04),
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
                enableEchoCanceler = intent.getBooleanExtra(
                    EXTRA_ENABLE_ECHO_CANCELER,
                    true,
                ),
                enableNoiseSuppressor = intent.getBooleanExtra(
                    EXTRA_ENABLE_NOISE_SUPPRESSOR,
                    true,
                ),
                enableAutomaticGainControl = intent.getBooleanExtra(
                    EXTRA_ENABLE_AUTOMATIC_GAIN_CONTROL,
                    false,
                ),
                enableMicDucking = intent.getBooleanExtra(EXTRA_ENABLE_MIC_DUCKING, true),
                micEchoDuckedGain = intent.getDoubleExtra(EXTRA_MIC_ECHO_DUCKED_GAIN, 0.25),
                systemActiveThreshold = intent.getDoubleExtra(
                    EXTRA_SYSTEM_ACTIVE_THRESHOLD,
                    0.02,
                ),
                micSpeechThreshold = intent.getDoubleExtra(EXTRA_MIC_SPEECH_THRESHOLD, 0.04),
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
