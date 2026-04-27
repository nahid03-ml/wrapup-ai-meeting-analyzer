import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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
