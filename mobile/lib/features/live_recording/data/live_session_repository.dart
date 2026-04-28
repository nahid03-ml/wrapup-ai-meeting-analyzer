import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../meetings/data/meetings_repository.dart';

class LiveSessionStartResult {
  const LiveSessionStartResult({
    required this.meetingId,
    required this.sessionId,
    required this.languageCode,
  });

  final String meetingId;
  final String sessionId;
  final String languageCode;
}

class LiveSessionRepository {
  LiveSessionRepository({
    required SupabaseClient client,
    required MeetingsRepository meetingsRepository,
  }) : _client = client,
       _meetingsRepository = meetingsRepository;

  final SupabaseClient _client;
  final MeetingsRepository _meetingsRepository;

  /// Creates the rows required before opening the backend live WebSocket.
  ///
  /// This mirrors the website live flow: create a meeting with source=live,
  /// create a session with language_detected, then connect to
  /// /ws/live-transcription/{session_id}. There is no FastAPI start endpoint.
  Future<LiveSessionStartResult> createLiveSession({
    required String title,
    required String languageCode,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('A signed-in user is required.');
    }

    final trimmedTitle = title.trim();
    final trimmedLanguage = languageCode.trim();
    if (trimmedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', 'Meeting title is required.');
    }
    if (trimmedLanguage.isEmpty) {
      throw ArgumentError.value(
        languageCode,
        'languageCode',
        'Meeting language is required.',
      );
    }

    String? createdMeetingId;
    try {
      final meeting = await _meetingsRepository.createMeeting(
        title: trimmedTitle,
        source: 'live',
      );
      createdMeetingId = meeting.id;

      final row = await _client
          .from('sessions')
          .insert({
            'meeting_id': createdMeetingId,
            'language_detected': trimmedLanguage,
          })
          .select('id')
          .single();

      return LiveSessionStartResult(
        meetingId: createdMeetingId,
        sessionId: _asStringKeyedMap(row)['id'] as String,
        languageCode: trimmedLanguage,
      );
    } catch (_) {
      if (createdMeetingId != null) {
        try {
          await _meetingsRepository.hardDeleteMeetingForRollback(
            createdMeetingId,
          );
        } catch (_) {
          // Best-effort rollback only. Preserve the original insertion error.
        }
      }
      rethrow;
    }
  }
}

Map<String, dynamic> _asStringKeyedMap(dynamic value) {
  return Map<String, dynamic>.from(value as Map);
}

final liveSessionRepositoryProvider = Provider<LiveSessionRepository>((ref) {
  return LiveSessionRepository(
    client: ref.watch(supabaseClientProvider),
    meetingsRepository: ref.watch(meetingsRepositoryProvider),
  );
});
