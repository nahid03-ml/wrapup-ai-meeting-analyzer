package com.wrapupai.mobile.livecapture

object LiveCaptureAudioContract {
    const val TARGET_SAMPLE_RATE_HZ = 16000
    const val CHANNEL_COUNT = 1
    const val BITS_PER_SAMPLE = 16
    const val BYTES_PER_SAMPLE = 2

    const val SOURCE_SYSTEM_PLAYBACK = "systemPlayback"

    const val LEVEL_EMIT_INTERVAL_MS = 250L
    const val NO_DATA_STATUS_INTERVAL_MS = 2000L
    const val NO_FRAME_WARNING_MS = 5000L
    const val SILENCE_WARNING_MS = 5000L
    const val SILENCE_LEVEL_THRESHOLD = 0.01

    const val STATUS_AUDIO_RECORD_BUILT = "audioRecordBuilt"
    const val STATUS_AUDIO_RECORD_START_REQUESTED = "audioRecordStartRequested"
    const val STATUS_AUDIO_RECORD_RECORDING = "audioRecordRecording"
    const val STATUS_PLAYBACK_CAPTURE_STARTING = "playbackCaptureStarting"
    const val STATUS_PLAYBACK_CAPTURE_STARTED = "playbackCaptureStarted"
    const val STATUS_PLAYBACK_CAPTURE_STOP_REQUESTED = "playbackCaptureStopRequested"
    const val STATUS_PLAYBACK_CAPTURE_STOPPED = "playbackCaptureStopped"
    const val STATUS_PLAYBACK_READ_STARTED = "playbackReadStarted"
    const val STATUS_PLAYBACK_READ_NO_DATA = "playbackReadNoData"
    const val STATUS_PLAYBACK_FIRST_FRAME_READ = "playbackFirstFrameRead"
    const val STATUS_PLAYBACK_READ_STOPPED = "playbackReadStopped"
    const val STATUS_DEVICE_AUDIO_DETECTED = "deviceAudioDetected"

    const val WARNING_SYSTEM_PLAYBACK_SILENT = "systemPlaybackSilent"
    const val WARNING_PLAYBACK_CAPTURE_NO_FRAMES = "playbackCaptureNoFrames"

    const val ERROR_PLAYBACK_CAPTURE_UNSUPPORTED = "playbackCaptureUnsupported"
    const val ERROR_PROJECTION_UNAVAILABLE = "projectionUnavailable"
    const val ERROR_AUDIO_RECORD_INIT_FAILED = "audioRecordInitFailed"
    const val ERROR_AUDIO_RECORD_START_FAILED = "audioRecordStartFailed"
    const val ERROR_PLAYBACK_CAPTURE_READ_FAILED = "playbackCaptureReadFailed"
    const val ERROR_PLAYBACK_CAPTURE_SECURITY = "playbackCaptureSecurityError"
}
