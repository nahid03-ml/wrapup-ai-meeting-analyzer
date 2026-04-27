/// Mirrors a row from public.action_items.
///
/// Columns from migrations:
///   - 20260211151950_*: id, meeting_id, owner_id, title, is_completed,
///                        created_at, updated_at
///   - 20260224010500_*: session_id, assigned_to, deadline, metadata
class ActionItem {
  const ActionItem({
    required this.id,
    required this.meetingId,
    required this.ownerId,
    required this.title,
    required this.isCompleted,
    required this.createdAt,
    required this.updatedAt,
    required this.metadata,
    this.sessionId,
    this.assignedTo,
    this.deadline,
  });

  final String id;
  final String meetingId;
  final String ownerId;
  final String title;
  final bool isCompleted;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? sessionId;
  final String? assignedTo;
  final DateTime? deadline;
  final Map<String, dynamic> metadata;

  factory ActionItem.fromMap(Map<String, dynamic> map) => ActionItem(
    id: (map['id'] as String?) ?? '',
    meetingId: (map['meeting_id'] as String?) ?? '',
    ownerId: (map['owner_id'] as String?) ?? '',
    title: (map['title'] as String?) ?? '',
    isCompleted: (map['is_completed'] as bool?) ?? false,
    createdAt: _parseRequiredDate(map['created_at']),
    updatedAt: _parseRequiredDate(map['updated_at']),
    sessionId: map['session_id'] as String?,
    assignedTo: map['assigned_to'] as String?,
    deadline: _parseDate(map['deadline']),
    metadata: Map.unmodifiable(
      _asMap(map['metadata']) ?? const <String, dynamic>{},
    ),
  );

  /// Partial-update payload. Mirrors the website's toggle flow in
  /// src/hooks/useActionItems.ts and allows future data-only updates.
  Map<String, dynamic> toUpdate({
    String? title,
    bool? isCompleted,
    String? sessionId,
    String? assignedTo,
    DateTime? deadline,
    Map<String, dynamic>? metadata,
  }) {
    final payload = <String, dynamic>{};
    if (title != null) payload['title'] = title;
    if (isCompleted != null) payload['is_completed'] = isCompleted;
    if (sessionId != null) payload['session_id'] = sessionId;
    if (assignedTo != null) payload['assigned_to'] = assignedTo;
    if (deadline != null) {
      payload['deadline'] = deadline.toUtc().toIso8601String();
    }
    if (metadata != null) payload['metadata'] = metadata;
    return payload;
  }
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value == null) return null;
  if (value is! Map) return null;
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
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
