import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/action_item.dart';
import '../data/action_items_repository.dart';

const kActionItemsPollInterval = Duration(seconds: 3);

final actionItemsProvider = FutureProvider.autoDispose<List<ActionItem>>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const <ActionItem>[];
  }

  final repository = ref.watch(actionItemsRepositoryProvider);

  final timer = Timer.periodic(kActionItemsPollInterval, (_) {
    ref.invalidateSelf();
  });
  ref.onDispose(timer.cancel);

  final subscription = repository.subscribe().listen((_) {
    ref.invalidateSelf();
  });
  ref.onDispose(() {
    unawaited(subscription.cancel());
  });

  return repository.fetchAllForCurrentUser();
});
