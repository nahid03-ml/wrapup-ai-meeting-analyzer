import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import 'meeting.dart';

class MeetingsRepository {
  MeetingsRepository(this._client);

  final SupabaseClient _client;

  /// Mirrors src/hooks/useMeetings.ts:
  /// meetings, excluding soft-deleted rows, newest first.
  Future<List<Meeting>> fetchAllForCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      return const [];
    }

    final rows = await _client
        .from('meetings')
        .select(
          '*, sessions(id, meeting_id, transcript, summary, language_detected, created_at, analytics_data, processing_status)',
        )
        .eq('is_deleted', false)
        .order('created_at', ascending: false)
        .order('created_at', referencedTable: 'sessions', ascending: true);

    return rows.map((row) => Meeting.fromMap(_asRow(row))).toList();
  }

  Future<Meeting> createMeeting({required String title, String? source}) async {
    final userId = _requireCurrentUserId();
    final payload = <String, dynamic>{'title': title, 'owner_id': userId};
    if (source != null && source.trim().isNotEmpty) {
      payload['source'] = source;
    }

    final row = await _client
        .from('meetings')
        .insert(payload)
        .select()
        .single();
    return Meeting.fromMap(_asRow(row));
  }

  Future<void> updateMeeting(String id, Map<String, dynamic> fields) async {
    if (fields.isEmpty) {
      return;
    }
    await _client.from('meetings').update(fields).eq('id', id);
  }

  Future<Meeting> scheduleMeeting({
    required String title,
    required DateTime scheduledAt,
    DateTime? scheduledEndAt,
  }) async {
    final userId = _requireCurrentUserId();
    final payload = <String, dynamic>{
      'title': title,
      'owner_id': userId,
      'scheduled_at': scheduledAt.toUtc().toIso8601String(),
    };
    if (scheduledEndAt != null) {
      payload['scheduled_end_at'] = scheduledEndAt.toUtc().toIso8601String();
    }

    final row = await _client
        .from('meetings')
        .insert(payload)
        .select()
        .single();
    return Meeting.fromMap(_asRow(row));
  }

  Future<void> softDelete(String id) async {
    await _client.from('meetings').update({'is_deleted': true}).eq('id', id);
  }

  /// Rollback-only hard delete for meetings created during failed upload.
  /// Do not use for normal user deletion.
  Future<void> hardDeleteMeetingForRollback(String id) async {
    await _client.from('meetings').delete().eq('id', id);
  }

  /// Emits once for each public.meetings realtime change.
  Stream<void> subscribeMeetings() {
    final controller = StreamController<void>();
    final channel = _client.channel('meetings-realtime');

    channel
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'meetings',
          callback: (_) {
            if (!controller.isClosed) {
              controller.add(null);
            }
          },
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  String _requireCurrentUserId() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('A signed-in user is required.');
    }
    return userId;
  }
}

Map<String, dynamic> _asRow(dynamic value) {
  return Map<String, dynamic>.from(value as Map);
}

final meetingsRepositoryProvider = Provider<MeetingsRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return MeetingsRepository(client);
});
