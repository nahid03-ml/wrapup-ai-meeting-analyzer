/// Mirrors a row from public.meeting_ai_chats.
///
/// Columns from migrations/20260225090000_*:
///   - id, meeting_id, session_id, user_id, question, answer, created_at
class MeetingAiChat {
  const MeetingAiChat({
    required this.id,
    required this.meetingId,
    required this.userId,
    required this.question,
    required this.answer,
    required this.createdAt,
    this.sessionId,
  });

  final String id;
  final String meetingId;
  final String? sessionId;
  final String userId;
  final String question;
  final String answer;
  final DateTime createdAt;

  factory MeetingAiChat.fromMap(Map<String, dynamic> map) => MeetingAiChat(
    id: (map['id'] as String?) ?? '',
    meetingId: (map['meeting_id'] as String?) ?? '',
    sessionId: map['session_id'] as String?,
    userId: (map['user_id'] as String?) ?? '',
    question: (map['question'] as String?) ?? '',
    answer: (map['answer'] as String?) ?? '',
    createdAt: _parseRequiredDate(map['created_at']),
  );

  Map<String, dynamic> toUpdate({
    String? sessionId,
    String? question,
    String? answer,
  }) {
    final payload = <String, dynamic>{};
    if (sessionId != null) payload['session_id'] = sessionId;
    if (question != null) payload['question'] = question;
    if (answer != null) payload['answer'] = answer;
    return payload;
  }
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
