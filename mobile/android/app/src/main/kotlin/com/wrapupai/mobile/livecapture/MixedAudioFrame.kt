package com.wrapupai.mobile.livecapture

data class MixedAudioFrame(
    val samples: ShortArray,
    val sampleRateHz: Int = LiveCaptureAudioContract.TARGET_SAMPLE_RATE_HZ,
    val channelCount: Int = LiveCaptureAudioContract.CHANNEL_COUNT,
    val clippingCount: Int = 0,
)
