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
}

class LiveIdle extends LiveRecordingState {
  const LiveIdle();
}

class LiveCreatingSession extends LiveRecordingState {
  const LiveCreatingSession({super.languageCode});
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
  });

  final String errorMessage;
  final Object? error;
}
