import 'session.dart';

/// Mirrors a row from public.meetings.
///
/// Column reference:
///   - migrations/20260211151950_*: id, title, owner_id, created_at, updated_at, is_deleted
///   - migrations/20260225103000_*: scheduled_at, scheduled_end_at, actual_ended_at, duration_minutes
///   - migrations/20260421120000_*: source ('recorded' | 'uploaded' | 'live')
class Meeting {
  const Meeting({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.isDeleted,
    this.scheduledAt,
    this.scheduledEndAt,
    this.actualEndedAt,
    this.durationMinutes,
    this.source,
    this.sessions = const [],
  });

  final String id;
  final String ownerId;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final DateTime? scheduledAt;
  final DateTime? scheduledEndAt;
  final DateTime? actualEndedAt;
  final int? durationMinutes;
  final String? source;
  final List<MeetingSession> sessions;

  factory Meeting.fromMap(Map<String, dynamic> map) => Meeting(
    id: map['id'] as String,
    ownerId: map['owner_id'] as String,
    title: (map['title'] as String?) ?? 'Untitled Meeting',
    createdAt: _parseRequiredDate(map['created_at']),
    updatedAt: _parseRequiredDate(map['updated_at']),
    isDeleted: (map['is_deleted'] as bool?) ?? false,
    scheduledAt: _parseDate(map['scheduled_at']),
    scheduledEndAt: _parseDate(map['scheduled_end_at']),
    actualEndedAt: _parseDate(map['actual_ended_at']),
    durationMinutes: _parseInt(map['duration_minutes']),
    source: map['source'] as String?,
    sessions: _parseSessions(map['sessions']),
  );

  MeetingSession? get latestSession => sessions.isEmpty ? null : sessions.last;

  bool get hasPendingSession => sessions.any((session) => session.isPending);

  /// Partial-update payload. Mirrors the website's TablesUpdate<'meetings'>
  /// usage in src/hooks/useMeetings.ts:77.
  Map<String, dynamic> toUpdate({
    String? title,
    DateTime? scheduledAt,
    DateTime? scheduledEndAt,
    DateTime? actualEndedAt,
    int? durationMinutes,
  }) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (scheduledAt != null) {
      payload['scheduled_at'] = scheduledAt.toUtc().toIso8601String();
    }
    if (scheduledEndAt != null) {
      payload['scheduled_end_at'] = scheduledEndAt.toUtc().toIso8601String();
    }
    if (actualEndedAt != null) {
      payload['actual_ended_at'] = actualEndedAt.toUtc().toIso8601String();
    }
    if (durationMinutes != null) {
      payload['duration_minutes'] = durationMinutes;
    }
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

int? _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return null;
}

List<MeetingSession> _parseSessions(dynamic value) {
  if (value is! List) return const <MeetingSession>[];

  final sessions = <MeetingSession>[];
  for (final item in value) {
    if (item is! Map) continue;
    try {
      sessions.add(MeetingSession.fromMap(_asStringKeyedMap(item)));
    } catch (_) {
      continue;
    }
  }
  sessions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return List.unmodifiable(sessions);
}

Map<String, dynamic> _asStringKeyedMap(Map<dynamic, dynamic> value) {
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}
