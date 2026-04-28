class LiveTranscriptionProtocol {
  const LiveTranscriptionProtocol._();

  static const webSocketPathPattern = '/ws/live-transcription/{session_id}';
  static const webSocketPathPrefix = '/ws/live-transcription';
  static const sessionIdPlaceholder = '{session_id}';

  static const languageQueryParam = 'lang';
  static const tokenQueryParam = 'token';

  static const clientStopType = 'stop';
  static const stopControlMessage = <String, String>{
    'type': clientStopType,
  };

  static String webSocketPathForSession(String sessionId) {
    return '$webSocketPathPrefix/${Uri.encodeComponent(sessionId)}';
  }
}

class LiveAudioFormat {
  const LiveAudioFormat({
    required this.encoding,
    required this.sampleRateHz,
    required this.channelCount,
    required this.bitsPerSample,
    required this.byteOrder,
    required this.container,
    required this.streamShape,
  });

  final String encoding;
  final int sampleRateHz;
  final int channelCount;
  final int bitsPerSample;
  final String byteOrder;
  final String container;
  final String streamShape;
}

const backendLiveAudioFormat = LiveAudioFormat(
  encoding: 'linear16',
  sampleRateHz: 16000,
  channelCount: 1,
  bitsPerSample: 16,
  byteOrder: 'little-endian',
  container: 'raw-pcm',
  streamShape: 'single-mixed-stream',
);

class LiveSessionCreationStep {
  const LiveSessionCreationStep({
    required this.order,
    required this.title,
    required this.description,
  });

  final int order;
  final String title;
  final String description;
}

class LiveSessionCreationContract {
  const LiveSessionCreationContract({
    required this.meetingSource,
    required this.steps,
  });

  final String meetingSource;
  final List<LiveSessionCreationStep> steps;
}

const liveSessionCreationContract = LiveSessionCreationContract(
  meetingSource: 'live',
  steps: <LiveSessionCreationStep>[
    LiveSessionCreationStep(
      order: 1,
      title: 'Create meeting row',
      description: 'Insert a Supabase meetings row with source = live.',
    ),
    LiveSessionCreationStep(
      order: 2,
      title: 'Create session row',
      description:
          'Insert a Supabase sessions row with meeting_id and language_detected.',
    ),
    LiveSessionCreationStep(
      order: 3,
      title: 'Open live WebSocket',
      description:
          'Open /ws/live-transcription/{session_id} with lang and token query params.',
    ),
  ],
);
