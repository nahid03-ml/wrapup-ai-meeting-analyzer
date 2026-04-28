enum LiveBackendEventType {
  transcript('transcript'),
  warning('warning'),
  info('info'),
  error('error'),
  done('done'),
  unknown('unknown');

  const LiveBackendEventType(this.wireValue);

  final String wireValue;

  static LiveBackendEventType fromWireValue(String? value) {
    for (final type in LiveBackendEventType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return LiveBackendEventType.unknown;
  }
}

abstract class LiveBackendEvent {
  const LiveBackendEvent(this.eventType);

  final LiveBackendEventType eventType;

  String get type => eventType.wireValue;

  factory LiveBackendEvent.fromJson(Map<String, dynamic> json) {
    final type = LiveBackendEventType.fromWireValue(json['type'] as String?);
    return switch (type) {
      LiveBackendEventType.transcript => LiveTranscriptEvent.fromJson(json),
      LiveBackendEventType.warning ||
      LiveBackendEventType.info ||
      LiveBackendEventType.error => LiveMessageEvent.fromJson(json, type),
      LiveBackendEventType.done => LiveDoneEvent.fromJson(json),
      LiveBackendEventType.unknown => LiveUnknownEvent(json),
    };
  }

  Map<String, dynamic> toJson();
}

class LiveTranscriptEvent extends LiveBackendEvent {
  const LiveTranscriptEvent({
    required this.text,
    required this.speaker,
    required this.isFinal,
    required this.confidence,
  }) : super(LiveBackendEventType.transcript);

  final String text;
  final int? speaker;
  final bool isFinal;
  final double confidence;

  factory LiveTranscriptEvent.fromJson(Map<String, dynamic> json) {
    return LiveTranscriptEvent(
      text: (json['text'] as String?) ?? '',
      speaker: _intOrNull(json['speaker']),
      isFinal: json['is_final'] == true,
      confidence: _doubleOrZero(json['confidence']),
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'text': text,
    'speaker': speaker,
    'is_final': isFinal,
    'confidence': confidence,
  };
}

class LiveMessageEvent extends LiveBackendEvent {
  const LiveMessageEvent({
    required LiveBackendEventType eventType,
    required this.message,
  }) : assert(
         eventType == LiveBackendEventType.warning ||
             eventType == LiveBackendEventType.info ||
             eventType == LiveBackendEventType.error,
       ),
       super(eventType);

  final String message;

  factory LiveMessageEvent.fromJson(
    Map<String, dynamic> json,
    LiveBackendEventType eventType,
  ) {
    return LiveMessageEvent(
      eventType: eventType,
      message: (json['message'] as String?) ?? '',
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'message': message,
  };
}

class LiveDoneEvent extends LiveBackendEvent {
  const LiveDoneEvent({
    required this.sessionId,
    required this.transcript,
    required this.usedGroqFallback,
  }) : super(LiveBackendEventType.done);

  final String sessionId;
  final String transcript;
  final bool usedGroqFallback;

  factory LiveDoneEvent.fromJson(Map<String, dynamic> json) {
    return LiveDoneEvent(
      sessionId: (json['session_id'] as String?) ?? '',
      transcript: (json['transcript'] as String?) ?? '',
      usedGroqFallback: json['used_groq_fallback'] == true,
    );
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'type': type,
    'session_id': sessionId,
    'transcript': transcript,
    'used_groq_fallback': usedGroqFallback,
  };
}

class LiveUnknownEvent extends LiveBackendEvent {
  const LiveUnknownEvent(this.payload) : super(LiveBackendEventType.unknown);

  final Map<String, dynamic> payload;

  @override
  Map<String, dynamic> toJson() => payload;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _doubleOrZero(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}
