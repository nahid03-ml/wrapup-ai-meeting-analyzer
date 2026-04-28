import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../meetings/data/meeting_detail_repository.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../subscription/data/subscription.dart';

class UploadLimits {
  const UploadLimits({
    required this.planTier,
    required this.label,
    required this.sessionsToday,
    required this.sessionsPerDay,
    required this.maxFileSizeMb,
    required this.maxDurationMinutes,
  });

  final PlanTier planTier;
  final String label;
  final int sessionsToday;
  final int? sessionsPerDay;
  final int? maxFileSizeMb;
  final int? maxDurationMinutes;

  bool get isUnlimited => planTier == PlanTier.enterprise;

  bool get isAtDailyLimit {
    final cap = sessionsPerDay;
    return cap != null && sessionsToday >= cap;
  }

  int? get maxFileSizeBytes {
    final maxMb = maxFileSizeMb;
    if (maxMb == null) {
      return null;
    }
    return maxMb * 1024 * 1024;
  }

  static UploadLimits forTier(PlanTier tier, {required int sessionsToday}) {
    return switch (tier) {
      PlanTier.free => UploadLimits(
        planTier: tier,
        label: 'Free',
        sessionsToday: sessionsToday,
        sessionsPerDay: 3,
        maxFileSizeMb: 100,
        maxDurationMinutes: 30,
      ),
      PlanTier.plus => UploadLimits(
        planTier: tier,
        label: 'Plus',
        sessionsToday: sessionsToday,
        sessionsPerDay: 20,
        maxFileSizeMb: 500,
        maxDurationMinutes: 120,
      ),
      PlanTier.business => UploadLimits(
        planTier: tier,
        label: 'Business',
        sessionsToday: sessionsToday,
        sessionsPerDay: 50,
        maxFileSizeMb: 2000,
        maxDurationMinutes: 480,
      ),
      PlanTier.enterprise => UploadLimits(
        planTier: tier,
        label: 'Enterprise',
        sessionsToday: sessionsToday,
        sessionsPerDay: null,
        maxFileSizeMb: null,
        maxDurationMinutes: null,
      ),
    };
  }
}

final uploadLimitsProvider = FutureProvider.autoDispose<UploadLimits>((
  ref,
) async {
  final subscription = await ref.watch(subscriptionProvider.future);
  final tier = subscription?.planTier ?? PlanTier.free;

  final repository = ref.watch(meetingDetailRepositoryProvider);
  final sessionsToday = await repository
      .countSessionsCreatedSinceForCurrentUser(_localStartOfToday());

  return UploadLimits.forTier(tier, sessionsToday: sessionsToday);
});

DateTime _localStartOfToday() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
