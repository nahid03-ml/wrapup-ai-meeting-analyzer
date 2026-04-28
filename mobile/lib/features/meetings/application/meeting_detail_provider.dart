import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/backend_api.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/meeting.dart';
import '../data/meeting_ai_chat.dart';
import '../data/meeting_detail_repository.dart';
import '../data/note.dart';
import '../data/participant.dart';
import '../data/session.dart';

const kMeetingDetailPollInterval = Duration(seconds: 3);

final meetingProvider = FutureProvider.autoDispose.family<Meeting, String>((
  ref,
  meetingId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    throw StateError('A signed-in user is required.');
  }

  ref.watch(_meetingDetailRealtimeProvider(meetingId));
  final repository = ref.watch(meetingDetailRepositoryProvider);
  return repository.fetchMeeting(meetingId);
});

final sessionsProvider = FutureProvider.autoDispose
    .family<List<MeetingSession>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <MeetingSession>[];
      }

      ref.watch(_meetingDetailRealtimeProvider(meetingId));
      final repository = ref.watch(meetingDetailRepositoryProvider);
      final sessions = await repository.fetchSessions(meetingId);
      if (sessions.any((session) => session.isPending)) {
        final timer = Timer(kMeetingDetailPollInterval, ref.invalidateSelf);
        ref.onDispose(timer.cancel);
      }
      return sessions;
    });

final notesProvider = FutureProvider.autoDispose.family<List<Note>, String>((
  ref,
  meetingId,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const <Note>[];
  }

  ref.watch(_meetingDetailRealtimeProvider(meetingId));
  final repository = ref.watch(meetingDetailRepositoryProvider);
  return repository.fetchNotes(meetingId);
});

final chatsProvider = FutureProvider.autoDispose
    .family<List<MeetingAiChat>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <MeetingAiChat>[];
      }

      ref.watch(_meetingDetailRealtimeProvider(meetingId));
      final repository = ref.watch(meetingDetailRepositoryProvider);
      return repository.fetchChats(meetingId);
    });

final participantsProvider = FutureProvider.autoDispose
    .family<List<Participant>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <Participant>[];
      }

      ref.watch(_meetingDetailRealtimeProvider(meetingId));
      final repository = ref.watch(meetingDetailRepositoryProvider);
      return repository.fetchParticipants(meetingId);
    });

final audioPlayableUrlProvider = FutureProvider.autoDispose
    .family<String?, MeetingSession>((ref, session) async {
      final audioRef = session.audioFileUrl?.trim();
      _debugAudioRef(session: session, audioRef: audioRef);
      if (audioRef == null || audioRef.isEmpty) {
        return null;
      }

      if (audioRef.startsWith('meeting-files/')) {
        final path = audioRef.substring('meeting-files/'.length).trim();
        if (path.isEmpty) {
          throw StateError('Meeting audio storage path is empty.');
        }
        final client = ref.watch(supabaseClientProvider);
        try {
          final signedUrl = await client.storage
              .from('meeting-files')
              .createSignedUrl(path, 3600);
          if (signedUrl.trim().isEmpty) {
            throw StateError('Supabase returned an empty audio signed URL.');
          }
          _debugAudioLog(
            'signed URL created for session=${session.id} '
            'bucket=meeting-files objectPathLength=${path.length} '
            'filename=${_lastPathSegment(path)} signedUrlLength=${signedUrl.length}',
          );
          return signedUrl.trim();
        } catch (error) {
          _debugAudioLog(
            'signed URL failed for session=${session.id} '
            'bucket=meeting-files objectPathLength=${path.length} '
            'filename=${_lastPathSegment(path)} error=${_safeError(error)}',
          );
          rethrow;
        }
      }

      if (audioRef.startsWith('r2:')) {
        final api = ref.watch(backendApiProvider);
        try {
          final response = await api.getSessionAudioUrl(session.id);
          final url = response['url'];
          if (url is String && url.trim().isNotEmpty) {
            _debugAudioLog(
              'R2 audio URL created for session=${session.id} '
              'urlLength=${url.length}',
            );
            return url.trim();
          }
          throw StateError('Backend returned an empty audio URL.');
        } catch (error) {
          _debugAudioLog(
            'R2 audio URL failed for session=${session.id} '
            'error=${_safeError(error)}',
          );
          rethrow;
        }
      }

      _debugAudioLog(
        'using raw audio URL fallback for session=${session.id} '
        'refLength=${audioRef.length}',
      );
      return audioRef;
    });

void _debugAudioRef({
  required MeetingSession session,
  required String? audioRef,
}) {
  if (!kDebugMode) return;
  final ref = audioRef?.trim();
  if (ref == null || ref.isEmpty) {
    _debugAudioLog('session=${session.id} audioRef=empty');
    return;
  }
  if (ref.startsWith('meeting-files/')) {
    final path = ref.substring('meeting-files/'.length).trim();
    _debugAudioLog(
      'session=${session.id} audioRef=storage bucket=meeting-files '
      'objectPathLength=${path.length} filename=${_lastPathSegment(path)}',
    );
    return;
  }
  if (ref.startsWith('r2:')) {
    _debugAudioLog('session=${session.id} audioRef=r2 refLength=${ref.length}');
    return;
  }
  _debugAudioLog('session=${session.id} audioRef=raw refLength=${ref.length}');
}

String _lastPathSegment(String path) {
  final segments = path.split('/').where((segment) => segment.isNotEmpty);
  return segments.isEmpty ? 'unknown' : segments.last;
}

String _safeError(Object error) {
  return error.toString().replaceAll(RegExp(r'https?://\S+'), '[url]');
}

void _debugAudioLog(String message) {
  if (!kDebugMode) return;
  developer.log(message, name: 'WrapUpAudio');
}

final _meetingDetailRealtimeProvider = StreamProvider.autoDispose
    .family<int, String>((ref, meetingId) async* {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return;
      }

      final repository = ref.watch(meetingDetailRepositoryProvider);
      var tick = 0;
      await for (final _ in repository.subscribeMeetingDetail(meetingId)) {
        yield ++tick;
      }
    });
