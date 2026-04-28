import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../new_meeting/application/upload_limits_provider.dart';
import '../../subscription/data/subscription.dart';

class LiveLimits {
  const LiveLimits({
    required this.planTier,
    required this.label,
    required this.sessionsToday,
    required this.sessionsPerDay,
  });

  final PlanTier planTier;
  final String label;
  final int sessionsToday;
  final int? sessionsPerDay;

  bool get isUnlimited => planTier == PlanTier.enterprise;

  bool get isAtDailyLimit {
    final cap = sessionsPerDay;
    return cap != null && sessionsToday >= cap;
  }
}

final liveLimitsProvider = FutureProvider.autoDispose<LiveLimits>((ref) async {
  final uploadLimits = await ref.watch(uploadLimitsProvider.future);
  return LiveLimits(
    planTier: uploadLimits.planTier,
    label: uploadLimits.label,
    sessionsToday: uploadLimits.sessionsToday,
    sessionsPerDay: uploadLimits.sessionsPerDay,
  );
});
