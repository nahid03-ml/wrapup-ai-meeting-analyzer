/// Mirrors a row from public.participants.
///
/// Columns from migrations/20260211151950_*:
///   - id, meeting_id, name, email
class Participant {
  const Participant({
    required this.id,
    required this.meetingId,
    required this.name,
    this.email,
  });

  final String id;
  final String meetingId;
  final String name;
  final String? email;

  factory Participant.fromMap(Map<String, dynamic> map) => Participant(
    id: (map['id'] as String?) ?? '',
    meetingId: (map['meeting_id'] as String?) ?? '',
    name: (map['name'] as String?) ?? '',
    email: map['email'] as String?,
  );

  Map<String, dynamic> toUpdate({String? name, String? email}) {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (email != null) payload['email'] = email;
    return payload;
  }
}
