import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/profile_repository.dart';

/// Stream of the current user's profile. Emits:
///   - null when signed out
///   - the UserProfile row when signed in (and the row exists)
///
/// Re-fetches when the user changes (sign-in, sign-out).
final currentProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final repo = ref.watch(profileRepositoryProvider);
  return repo.fetchById(user.id);
});
