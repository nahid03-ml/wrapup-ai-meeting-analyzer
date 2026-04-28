import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import 'meeting.dart';
import 'meeting_ai_chat.dart';
import 'note.dart';
import 'participant.dart';
import 'session.dart';

class MeetingDetailRepository {
  MeetingDetailRepository(this._client);

  final SupabaseClient _client;

  Future<Meeting> fetchMeeting(String id) async {
    final row = await _client.from('meetings').select().eq('id', id).single();
    return Meeting.fromMap(_asRow(row));
  }

  /// Mirrors src/hooks/useMeetingDetail.ts: sessions newest first.
  Future<List<MeetingSession>> fetchSessions(String meetingId) async {
    final rows = await _client
        .from('sessions')
        .select()
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: false);

    return rows.map((row) => MeetingSession.fromMap(_asRow(row))).toList();
  }

  /// Mirrors src/hooks/useMeetingDetail.ts: notes by latest update.
  Future<List<Note>> fetchNotes(String meetingId) async {
    final rows = await _client
        .from('notes')
        .select()
        .eq('meeting_id', meetingId)
        .order('updated_at', ascending: false);

    return rows.map((row) => Note.fromMap(_asRow(row))).toList();
  }

  /// Mirrors src/hooks/useMeetingDetail.ts: chat history oldest first.
  Future<List<MeetingAiChat>> fetchChats(String meetingId) async {
    final rows = await _client
        .from('meeting_ai_chats')
        .select()
        .eq('meeting_id', meetingId)
        .order('created_at', ascending: true);

    return rows.map((row) => MeetingAiChat.fromMap(_asRow(row))).toList();
  }

  Future<List<Participant>> fetchParticipants(String meetingId) async {
    final rows = await _client
        .from('participants')
        .select()
        .eq('meeting_id', meetingId);

    return rows.map((row) => Participant.fromMap(_asRow(row))).toList();
  }

  Future<int> countSessionsCreatedSinceForCurrentUser(
    DateTime createdSince,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return 0;
    }

    final rows = await _client
        .from('sessions')
        .select('id, meetings!inner(owner_id)')
        .eq('meetings.owner_id', userId)
        .gte('created_at', createdSince.toUtc().toIso8601String());

    return rows.length;
  }

  Future<MeetingSession> insertSessionForUpload({
    required String meetingId,
    required String audioFileUrl,
    required String language,
  }) async {
    final row = await _client
        .from('sessions')
        .insert({
          'meeting_id': meetingId,
          'audio_file_url': audioFileUrl,
          'language_detected': language,
        })
        .select()
        .single();
    return MeetingSession.fromMap(_asRow(row));
  }

  Future<Note> createNote({
    required String meetingId,
    required String content,
  }) async {
    final row = await _client
        .from('notes')
        .insert({'meeting_id': meetingId, 'content': content})
        .select()
        .single();
    return Note.fromMap(_asRow(row));
  }

  Future<void> updateNote(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) {
      return;
    }
    await _client.from('notes').update(fields).eq('id', id);
  }

  Future<void> deleteNote(String id) async {
    await _client.from('notes').delete().eq('id', id);
  }

  Future<Participant> insertParticipant({
    required String meetingId,
    required String name,
    String? email,
  }) async {
    final payload = <String, dynamic>{'meeting_id': meetingId, 'name': name};
    if (email != null) {
      payload['email'] = email;
    }

    final row = await _client
        .from('participants')
        .insert(payload)
        .select()
        .single();
    return Participant.fromMap(_asRow(row));
  }

  Future<MeetingAiChat> insertAiChat({
    String? sessionId,
    required String meetingId,
    required String userId,
    required String question,
    required String answer,
  }) async {
    final payload = <String, dynamic>{
      'meeting_id': meetingId,
      'user_id': userId,
      'question': question,
      'answer': answer,
    };
    if (sessionId != null && sessionId.trim().isNotEmpty) {
      payload['session_id'] = sessionId;
    }

    final row = await _client
        .from('meeting_ai_chats')
        .insert(payload)
        .select()
        .single();
    return MeetingAiChat.fromMap(_asRow(row));
  }

  Future<void> updateSession(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) {
      return;
    }
    await _client.from('sessions').update(fields).eq('id', id);
  }

  /// Emits when any practical meeting-detail table changes for [meetingId].
  Stream<void> subscribeMeetingDetail(String meetingId) {
    final controller = StreamController<void>();
    final channel = _client.channel('meeting-detail-$meetingId');

    void notify(PostgresChangePayload _) {
      if (!controller.isClosed) {
        controller.add(null);
      }
    }

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: meetingId,
          ),
          callback: notify,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'sessions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'meeting_id',
            value: meetingId,
          ),
          callback: notify,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'meeting_id',
            value: meetingId,
          ),
          callback: notify,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'participants',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'meeting_id',
            value: meetingId,
          ),
          callback: notify,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meeting_ai_chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'meeting_id',
            value: meetingId,
          ),
          callback: notify,
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }
}

Map<String, dynamic> _asRow(dynamic value) {
  return Map<String, dynamic>.from(value as Map);
}

final meetingDetailRepositoryProvider = Provider<MeetingDetailRepository>((
  ref,
) {
  final client = ref.watch(supabaseClientProvider);
  return MeetingDetailRepository(client);
});
