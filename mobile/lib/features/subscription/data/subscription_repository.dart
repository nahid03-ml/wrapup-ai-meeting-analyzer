import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import 'subscription.dart';

class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  /// Mirrors src/hooks/useSubscription.ts: latest active subscription
  /// for the current authenticated user.
  Future<Subscription?> fetchCurrent() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return null;
    }

    final row = await _client
        .from('subscriptions')
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (row == null) {
      return null;
    }
    return Subscription.fromMap(_asRow(row));
  }
}

Map<String, dynamic> _asRow(dynamic value) {
  return Map<String, dynamic>.from(value as Map);
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return SubscriptionRepository(client);
});
