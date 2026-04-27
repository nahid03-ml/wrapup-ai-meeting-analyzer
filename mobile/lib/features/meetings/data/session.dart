/// Mirrors a row from public.sessions.
///
/// Columns from migrations:
///   - 20260211151950_*: id, meeting_id, audio_file_url, transcript, summary (jsonb),
///                        language_detected, created_at
///   - 20260224010500_*: analytics_data (jsonb), processing_status, processing_progress,
///                        processing_message, processing_retries, processing_error, updated_at
///   - 20260317090000_*: language_confidence
class MeetingSession {
  const MeetingSession({
    required this.id,
    required this.meetingId,
    required this.createdAt,
    this.audioFileUrl,
    this.transcript,
    this.summary,
    this.languageDetected,
    this.languageConfidence,
    this.analyticsData,
    this.processingStatus,
    this.processingProgress,
    this.processingMessage,
    this.processingRetries,
    this.processingError,
    this.updatedAt,
  });

  final String id;
  final String meetingId;
  final DateTime createdAt;
  final String? audioFileUrl;
  final String? transcript;
  final Map<String, dynamic>? summary;
  final String? languageDetected;
  final double? languageConfidence;
  final Map<String, dynamic>? analyticsData;
  final String? processingStatus;
  final int? processingProgress;
  final String? processingMessage;
  final int? processingRetries;
  final String? processingError;
  final DateTime? updatedAt;

  /// True while the row is in a non-terminal processing state. Used by
  /// the polling provider to decide whether to keep re-fetching.
  /// Mirrors the website's check in src/hooks/useMeetingDetail.ts:60-72.
  bool get isPending {
    final status = _normalizeStatus(processingStatus);
    final analyticsStatus = _analyticsProcessingStatus;
    if (_isPendingStatus(status) || _isPendingStatus(analyticsStatus)) {
      return true;
    }
    if (_isTerminalStatus(status) || _isTerminalStatus(analyticsStatus)) {
      return false;
    }

    final hasAudio = audioFileUrl != null && audioFileUrl!.trim().isNotEmpty;
    final hasTranscript = transcript != null && transcript!.trim().isNotEmpty;
    final hasAnyOutput =
        hasTranscript || summary != null || analyticsData != null;
    return hasAudio && !hasAnyOutput;
  }

  String? get _analyticsProcessingStatus {
    final processing = analyticsData?['processing_status'];
    if (processing is String) return _normalizeStatus(processing);
    if (processing is Map) {
      return _normalizeStatus(processing['status']);
    }
    return null;
  }

  factory MeetingSession.fromMap(Map<String, dynamic> map) => MeetingSession(
    id: map['id'] as String,
    meetingId: map['meeting_id'] as String,
    createdAt: _parseRequiredDate(map['created_at']),
    audioFileUrl: map['audio_file_url'] as String?,
    transcript: map['transcript'] as String?,
    summary: _asMap(map['summary']),
    languageDetected: map['language_detected'] as String?,
    languageConfidence: (map['language_confidence'] as num?)?.toDouble(),
    analyticsData: _asMap(map['analytics_data']),
    processingStatus: map['processing_status'] as String?,
    processingProgress: (map['processing_progress'] as num?)?.toInt(),
    processingMessage: map['processing_message'] as String?,
    processingRetries: (map['processing_retries'] as num?)?.toInt(),
    processingError: map['processing_error'] as String?,
    updatedAt: _parseDate(map['updated_at']),
  );

  /// Partial-update payload. Mirrors useMeetingDetail.ts:175.
  Map<String, dynamic> toUpdate({
    String? transcript,
    Map<String, dynamic>? summary,
  }) {
    final payload = <String, dynamic>{};
    if (transcript != null) payload['transcript'] = transcript;
    if (summary != null) payload['summary'] = summary;
    return payload;
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value == null) return null;
  if (value is! Map) return null;
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}

String? _normalizeStatus(dynamic value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return trimmed.toLowerCase();
}

bool _isPendingStatus(String? status) {
  return status == 'queued' || status == 'processing' || status == 'pending';
}

bool _isTerminalStatus(String? status) {
  return status == 'completed' || status == 'failed';
}

DateTime _parseRequiredDate(dynamic value) {
  return _parseDate(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}
