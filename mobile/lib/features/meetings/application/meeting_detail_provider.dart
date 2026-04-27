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

  final repository = ref.watch(meetingDetailRepositoryProvider);
  _listenForDetailChanges(ref, repository, meetingId);
  return repository.fetchMeeting(meetingId);
});

final sessionsProvider = FutureProvider.autoDispose
    .family<List<MeetingSession>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <MeetingSession>[];
      }

      final repository = ref.watch(meetingDetailRepositoryProvider);
      _listenForDetailChanges(ref, repository, meetingId);
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

  final repository = ref.watch(meetingDetailRepositoryProvider);
  _listenForDetailChanges(ref, repository, meetingId);
  return repository.fetchNotes(meetingId);
});

final chatsProvider = FutureProvider.autoDispose
    .family<List<MeetingAiChat>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <MeetingAiChat>[];
      }

      final repository = ref.watch(meetingDetailRepositoryProvider);
      _listenForDetailChanges(ref, repository, meetingId);
      return repository.fetchChats(meetingId);
    });

final participantsProvider = FutureProvider.autoDispose
    .family<List<Participant>, String>((ref, meetingId) async {
      final user = ref.watch(currentUserProvider);
      if (user == null) {
        return const <Participant>[];
      }

      final repository = ref.watch(meetingDetailRepositoryProvider);
      _listenForDetailChanges(ref, repository, meetingId);
      return repository.fetchParticipants(meetingId);
    });

void _listenForDetailChanges(
  Ref ref,
  MeetingDetailRepository repository,
  String meetingId,
) {
  final subscription = repository.subscribeMeetingDetail(meetingId).listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
  });
}
