package com.wrapupai.mobile.livecapture

object LiveCaptureAudioContract {
    const val TARGET_SAMPLE_RATE_HZ = 16000
    const val CHANNEL_COUNT = 1
    const val BITS_PER_SAMPLE = 16
    const val BYTES_PER_SAMPLE = 2

    const val SOURCE_SYSTEM_PLAYBACK = "systemPlayback"
    const val SOURCE_MICROPHONE = "microphone"
    const val SOURCE_MIXED = "mixed"

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
    const val STATUS_SERVICE_STOP_REQUESTED = "serviceStopRequested"

    const val STATUS_MICROPHONE_CAPTURE_STARTING = "microphoneCaptureStarting"
    const val STATUS_MICROPHONE_AUDIO_RECORD_BUILT = "microphoneAudioRecordBuilt"
    const val STATUS_MICROPHONE_AUDIO_RECORD_START_REQUESTED =
        "microphoneAudioRecordStartRequested"
    const val STATUS_MICROPHONE_AUDIO_RECORD_RECORDING = "microphoneAudioRecordRecording"
    const val STATUS_MICROPHONE_CAPTURE_STARTED = "microphoneCaptureStarted"
    const val STATUS_MICROPHONE_CAPTURE_STOP_REQUESTED = "microphoneCaptureStopRequested"
    const val STATUS_MICROPHONE_CAPTURE_STOPPED = "microphoneCaptureStopped"
    const val STATUS_MICROPHONE_READ_STARTED = "microphoneReadStarted"
    const val STATUS_MICROPHONE_READ_NO_DATA = "microphoneReadNoData"
    const val STATUS_MICROPHONE_FIRST_FRAME_READ = "microphoneFirstFrameRead"
    const val STATUS_MICROPHONE_READ_STOPPED = "microphoneReadStopped"
    const val STATUS_MICROPHONE_AUDIO_DETECTED = "microphoneAudioDetected"
    const val STATUS_MICROPHONE_ECHO_CANCELER_ENABLED =
        "microphoneEchoCancelerEnabled"
    const val STATUS_MICROPHONE_NOISE_SUPPRESSOR_ENABLED =
        "microphoneNoiseSuppressorEnabled"
    const val STATUS_MICROPHONE_AUTOMATIC_GAIN_CONTROL_ENABLED =
        "microphoneAutomaticGainControlEnabled"
    const val STATUS_MICROPHONE_ECHO_CONTROL_UNAVAILABLE =
        "microphoneEchoControlUnavailable"

    const val STATUS_PLAYBACK_READ_STARTED = "playbackReadStarted"
    const val STATUS_PLAYBACK_READ_NO_DATA = "playbackReadNoData"
    const val STATUS_PLAYBACK_FIRST_FRAME_READ = "playbackFirstFrameRead"
    const val STATUS_PLAYBACK_READ_STOPPED = "playbackReadStopped"
    const val STATUS_DEVICE_AUDIO_DETECTED = "deviceAudioDetected"

    const val STATUS_MIXED_CAPTURE_STARTING = "mixedCaptureStarting"
    const val STATUS_MIXED_CAPTURE_STARTED = "mixedCaptureStarted"
    const val STATUS_MIXED_CAPTURE_STOPPED = "mixedCaptureStopped"
    const val STATUS_MIXED_READ_STARTED = "mixedReadStarted"
    const val STATUS_MIXED_OUTPUT_FRAME_READY = "mixedOutputFrameReady"
    const val STATUS_MIXED_AUDIO_DETECTED = "mixedAudioDetected"
    const val STATUS_MIXED_AUDIO_NO_INPUT = "mixedAudioNoInput"
    const val STATUS_MIXED_MIC_DUCKED_FOR_ECHO_CONTROL =
        "mixedMicDuckedForEchoControl"
    const val STATUS_MIXED_MIC_RESTORED_AFTER_ECHO_CONTROL =
        "mixedMicRestoredAfterEchoControl"

    const val WARNING_SYSTEM_PLAYBACK_SILENT = "systemPlaybackSilent"
    const val WARNING_PLAYBACK_CAPTURE_NO_FRAMES = "playbackCaptureNoFrames"
    const val WARNING_MICROPHONE_SILENT = "microphoneSilent"
    const val WARNING_MICROPHONE_CAPTURE_NO_FRAMES = "microphoneCaptureNoFrames"
    const val WARNING_MIXED_AUDIO_SILENT = "mixedAudioSilent"
    const val WARNING_MIXED_AUDIO_FRAME_DROP = "mixedAudioFrameDrop"
    const val WARNING_MIXED_AUDIO_CLIPPING = "mixedAudioClipping"
    const val WARNING_MIXED_AUDIO_ONLY_SYSTEM_ACTIVE = "mixedAudioOnlySystemActive"
    const val WARNING_MIXED_AUDIO_ONLY_MICROPHONE_ACTIVE =
        "mixedAudioOnlyMicrophoneActive"

    const val ERROR_PLAYBACK_CAPTURE_UNSUPPORTED = "playbackCaptureUnsupported"
    const val ERROR_PROJECTION_UNAVAILABLE = "projectionUnavailable"
    const val ERROR_AUDIO_RECORD_INIT_FAILED = "audioRecordInitFailed"
    const val ERROR_AUDIO_RECORD_START_FAILED = "audioRecordStartFailed"
    const val ERROR_PLAYBACK_CAPTURE_READ_FAILED = "playbackCaptureReadFailed"
    const val ERROR_PLAYBACK_CAPTURE_SECURITY = "playbackCaptureSecurityError"
    const val ERROR_MICROPHONE_AUDIO_RECORD_INIT_FAILED = "microphoneAudioRecordInitFailed"
    const val ERROR_MICROPHONE_AUDIO_RECORD_START_FAILED = "microphoneAudioRecordStartFailed"
    const val ERROR_MICROPHONE_CAPTURE_READ_FAILED = "microphoneCaptureReadFailed"
    const val ERROR_MICROPHONE_CAPTURE_SECURITY = "microphoneCaptureSecurityError"
}
