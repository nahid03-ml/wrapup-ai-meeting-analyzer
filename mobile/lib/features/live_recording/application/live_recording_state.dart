import 'live_transcript_line.dart';

sealed class LiveRecordingState {
  const LiveRecordingState({
    this.meetingId,
    this.sessionId,
    this.languageCode,
    this.transcriptLines = const <LiveTranscriptLine>[],
    this.messages = const <String>[],
    this.warnings = const <String>[],
    this.webSocketStatus = 'idle',
    this.captureStatus = 'idle',
    this.pcmChunksSent = 0,
    this.pcmChunksDropped = 0,
    this.lastPcmChunkBytes = 0,
    this.audioLevel = 0,
    this.hasAudioLevel = false,
    this.isAudioDetected = false,
    this.isPaused = false,
    this.pcmChunksSkippedWhilePaused = 0,
    this.captureStartedAt,
    this.captureStoppedAt,
    this.activeDuration = Duration.zero,
    this.pausedDuration = Duration.zero,
    this.totalSessionDuration = Duration.zero,
    this.lastTranscriptEventAt,
    this.lastPcmSentAt,
    this.lastBackendEventAt,
    this.appBackgroundCount = 0,
    this.appForegroundReturnCount = 0,
    this.lastBackgroundedAt,
    this.resumeCount = 0,
    this.lastResumeAt,
    this.pcmChunksSentAfterResume = 0,
    this.lastPcmSentAfterResumeAt,
    this.lastTranscriptAfterResumeAt,
    this.isSendingAudioAfterResume = false,
    this.pausedSilentKeepAliveChunksSent = 0,
    this.lastPausedSilentKeepAliveAt,
  });

  final String? meetingId;
  final String? sessionId;
  final String? languageCode;
  final List<LiveTranscriptLine> transcriptLines;
  final List<String> messages;
  final List<String> warnings;
  final String webSocketStatus;
  final String captureStatus;
  final int pcmChunksSent;
  final int pcmChunksDropped;
  final int lastPcmChunkBytes;
  final double audioLevel;
  final bool hasAudioLevel;
  final bool isAudioDetected;
  final bool isPaused;
  final int pcmChunksSkippedWhilePaused;
  final DateTime? captureStartedAt;
  final DateTime? captureStoppedAt;
  final Duration activeDuration;
  final Duration pausedDuration;
  final Duration totalSessionDuration;
  final DateTime? lastTranscriptEventAt;
  final DateTime? lastPcmSentAt;
  final DateTime? lastBackendEventAt;
  final int appBackgroundCount;
  final int appForegroundReturnCount;
  final DateTime? lastBackgroundedAt;
  final int resumeCount;
  final DateTime? lastResumeAt;
  final int pcmChunksSentAfterResume;
  final DateTime? lastPcmSentAfterResumeAt;
  final DateTime? lastTranscriptAfterResumeAt;
  final bool isSendingAudioAfterResume;
  final int pausedSilentKeepAliveChunksSent;
  final DateTime? lastPausedSilentKeepAliveAt;
}

class LiveIdle extends LiveRecordingState {
  const LiveIdle();
}

class LiveCreatingSession extends LiveRecordingState {
  const LiveCreatingSession({
    super.languageCode,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveConnecting extends LiveRecordingState {
  const LiveConnecting({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'connecting',
    super.captureStatus,
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveReadyNoCapture extends LiveRecordingState {
  const LiveReadyNoCapture({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'connected',
    super.captureStatus = 'not started',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveStartingCapture extends LiveRecordingState {
  const LiveStartingCapture({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'connected',
    super.captureStatus = 'starting',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveStreaming extends LiveRecordingState {
  const LiveStreaming({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'streaming',
    super.captureStatus = 'streaming',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LivePaused extends LiveRecordingState {
  const LivePaused({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'streaming',
    super.captureStatus = 'streaming',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  }) : super(isPaused: true);
}

class LiveResuming extends LiveRecordingState {
  const LiveResuming({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'streaming',
    super.captureStatus = 'streaming',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveStopping extends LiveRecordingState {
  const LiveStopping({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'stopping',
    super.captureStatus = 'stopping',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });
}

class LiveDone extends LiveRecordingState {
  const LiveDone({
    required String super.meetingId,
    required String super.sessionId,
    required String super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'closed',
    super.captureStatus = 'stopped',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
    this.finalTranscript = '',
    this.usedGroqFallback = false,
  });

  final String finalTranscript;
  final bool usedGroqFallback;
}

class LiveFailed extends LiveRecordingState {
  const LiveFailed({
    required this.errorMessage,
    this.error,
    super.meetingId,
    super.sessionId,
    super.languageCode,
    super.transcriptLines,
    super.messages,
    super.warnings,
    super.webSocketStatus = 'failed',
    super.captureStatus = 'stopped',
    super.pcmChunksSent,
    super.pcmChunksDropped,
    super.lastPcmChunkBytes,
    super.audioLevel,
    super.hasAudioLevel,
    super.isAudioDetected,
    super.isPaused,
    super.pcmChunksSkippedWhilePaused,
    super.captureStartedAt,
    super.captureStoppedAt,
    super.activeDuration,
    super.pausedDuration,
    super.totalSessionDuration,
    super.lastTranscriptEventAt,
    super.lastPcmSentAt,
    super.lastBackendEventAt,
    super.appBackgroundCount,
    super.appForegroundReturnCount,
    super.lastBackgroundedAt,
    super.resumeCount,
    super.lastResumeAt,
    super.pcmChunksSentAfterResume,
    super.lastPcmSentAfterResumeAt,
    super.lastTranscriptAfterResumeAt,
    super.isSendingAudioAfterResume,
    super.pausedSilentKeepAliveChunksSent,
    super.lastPausedSilentKeepAliveAt,
  });

  final String errorMessage;
  final Object? error;
}
