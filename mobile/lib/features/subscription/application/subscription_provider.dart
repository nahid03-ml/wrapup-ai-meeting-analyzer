import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/subscription.dart';
import '../data/subscription_repository.dart';

final subscriptionProvider = FutureProvider.autoDispose<Subscription?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return null;
  }

  final repository = ref.watch(subscriptionRepositoryProvider);
  return repository.fetchCurrent();
});
