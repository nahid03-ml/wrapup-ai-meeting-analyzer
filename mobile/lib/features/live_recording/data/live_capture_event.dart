enum LiveCaptureEventType {
  status('status'),
  warning('warning'),
  error('error'),
  stopped('stopped'),
  audioLevel('audioLevel'),
  unknown('unknown');

  const LiveCaptureEventType(this.wireValue);

  final String wireValue;

  static LiveCaptureEventType fromWireValue(String? value) {
    for (final type in LiveCaptureEventType.values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return LiveCaptureEventType.unknown;
  }
}

class LiveCaptureEvent {
  const LiveCaptureEvent({
    required this.eventType,
    required this.payload,
    this.status,
    this.message,
    this.code,
    this.level,
    this.isSilent,
    this.source,
    this.sampleRateHz,
    this.channelCount,
    this.bufferSizeBytes,
    this.readResult,
    this.recordingState,
    this.audioSource,
    this.clippingCount,
    this.systemFramesBuffered,
    this.micFramesBuffered,
    this.droppedFrames,
  });

  final LiveCaptureEventType eventType;
  final Map<String, dynamic> payload;
  final String? status;
  final String? message;
  final String? code;
  final double? level;
  final bool? isSilent;
  final String? source;
  final int? sampleRateHz;
  final int? channelCount;
  final int? bufferSizeBytes;
  final int? readResult;
  final int? recordingState;
  final String? audioSource;
  final int? clippingCount;
  final int? systemFramesBuffered;
  final int? micFramesBuffered;
  final int? droppedFrames;

  String get type => eventType.wireValue;

  factory LiveCaptureEvent.fromMap(Map<String, dynamic> map) {
    final eventType = LiveCaptureEventType.fromWireValue(
      map['type'] as String?,
    );
    return LiveCaptureEvent(
      eventType: eventType,
      payload: Map<String, dynamic>.unmodifiable(map),
      status: _stringOrNull(map['status']),
      message: _stringOrNull(map['message']),
      code: _stringOrNull(map['code']),
      level: _doubleOrNull(map['level']),
      isSilent: _boolOrNull(map['isSilent']),
      source: _stringOrNull(map['source']),
      sampleRateHz: _intOrNull(map['sampleRateHz']),
      channelCount: _intOrNull(map['channelCount']),
      bufferSizeBytes: _intOrNull(map['bufferSizeBytes']),
      readResult: _intOrNull(map['readResult']),
      recordingState: _intOrNull(map['recordingState']),
      audioSource: _stringOrNull(map['audioSource']),
      clippingCount: _intOrNull(map['clippingCount']),
      systemFramesBuffered: _intOrNull(map['systemFramesBuffered']),
      micFramesBuffered: _intOrNull(map['micFramesBuffered']),
      droppedFrames: _intOrNull(map['droppedFrames']),
    );
  }

  factory LiveCaptureEvent.unknown() {
    return const LiveCaptureEvent(
      eventType: LiveCaptureEventType.unknown,
      payload: <String, dynamic>{'type': 'unknown'},
    );
  }
}

class LiveProjectionResult {
  const LiveProjectionResult({
    required this.granted,
    this.message,
  });

  final bool granted;
  final String? message;

  factory LiveProjectionResult.fromMap(Map<String, dynamic> map) {
    return LiveProjectionResult(
      granted: map['granted'] == true,
      message: _stringOrNull(map['message']),
    );
  }

  factory LiveProjectionResult.denied(String message) {
    return LiveProjectionResult(granted: false, message: message);
  }
}

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

double? _doubleOrNull(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

bool? _boolOrNull(dynamic value) {
  if (value is bool) return value;
  if (value is String) return bool.tryParse(value);
  return null;
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
