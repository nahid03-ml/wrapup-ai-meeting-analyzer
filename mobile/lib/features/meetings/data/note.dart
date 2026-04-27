/// Mirrors a row from public.notes.
class Note {
  const Note({
    required this.id,
    required this.meetingId,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String meetingId;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Note.fromMap(Map<String, dynamic> map) => Note(
    id: map['id'] as String,
    meetingId: map['meeting_id'] as String,
    content: (map['content'] as String?) ?? '',
    createdAt: _parseRequiredDate(map['created_at']),
    updatedAt: _parseRequiredDate(map['updated_at']),
  );

  Map<String, dynamic> toUpdate({String? content}) {
    final payload = <String, dynamic>{};
    if (content != null) payload['content'] = content;
    return payload;
  }
}

DateTime _parseRequiredDate(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isNotEmpty) {
      final parsed = DateTime.tryParse(trimmed);
      if (parsed != null) return parsed;
    }
  }
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
