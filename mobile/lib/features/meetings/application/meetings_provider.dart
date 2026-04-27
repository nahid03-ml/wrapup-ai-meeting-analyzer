import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/meeting.dart';
import '../data/meetings_repository.dart';

final meetingsListProvider = FutureProvider.autoDispose<List<Meeting>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const <Meeting>[];
  }

  final repository = ref.watch(meetingsRepositoryProvider);
  final subscription = repository.subscribeMeetings().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
  });

  return repository.fetchAllForCurrentUser();
});
