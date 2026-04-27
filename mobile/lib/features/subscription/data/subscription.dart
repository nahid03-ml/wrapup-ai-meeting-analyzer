/// Plan tiers supported by src/lib/subscription.ts and the subscriptions table.
enum PlanTier {
  free,
  plus,
  business,
  enterprise;

  String get value => switch (this) {
    PlanTier.free => 'free',
    PlanTier.plus => 'plus',
    PlanTier.business => 'business',
    PlanTier.enterprise => 'enterprise',
  };

  static PlanTier fromValue(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    return switch (normalized) {
      'plus' || 'premium' => PlanTier.plus,
      'business' => PlanTier.business,
      'enterprise' => PlanTier.enterprise,
      _ => PlanTier.free,
    };
  }
}

/// Mirrors a row from public.subscriptions.
///
/// Columns from migrations:
///   - 20260216072119_*: id, user_id, plan_type, status, created_at
///   - 20260216102412_*: stripe_customer_id, stripe_subscription_id,
///                        current_period_start, current_period_end,
///                        cancel_at_period_end, updated_at
///   - 20260225121500_*: plan_type values free, plus, business, enterprise
class Subscription {
  const Subscription({
    required this.id,
    required this.userId,
    required this.planTier,
    required this.status,
    required this.createdAt,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.currentPeriodStart,
    this.currentPeriodEnd,
    this.cancelAtPeriodEnd = false,
    this.updatedAt,
  });

  final String id;
  final String userId;
  final PlanTier planTier;
  final String status;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;
  final DateTime? updatedAt;

  bool get isActive => status.trim().toLowerCase() == 'active';

  factory Subscription.fromMap(Map<String, dynamic> map) => Subscription(
    id: (map['id'] as String?) ?? '',
    userId: (map['user_id'] as String?) ?? '',
    planTier: PlanTier.fromValue(map['plan_type'] as String?),
    status: (map['status'] as String?) ?? 'inactive',
    stripeCustomerId: map['stripe_customer_id'] as String?,
    stripeSubscriptionId: map['stripe_subscription_id'] as String?,
    currentPeriodStart: _parseDate(map['current_period_start']),
    currentPeriodEnd: _parseDate(map['current_period_end']),
    cancelAtPeriodEnd: (map['cancel_at_period_end'] as bool?) ?? false,
    createdAt: _parseRequiredDate(map['created_at']),
    updatedAt: _parseDate(map['updated_at']),
  );

  Map<String, dynamic> toUpdate({
    PlanTier? planTier,
    String? status,
    String? stripeCustomerId,
    String? stripeSubscriptionId,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    bool? cancelAtPeriodEnd,
  }) {
    final payload = <String, dynamic>{};
    if (planTier != null) payload['plan_type'] = planTier.value;
    if (status != null) payload['status'] = status;
    if (stripeCustomerId != null) {
      payload['stripe_customer_id'] = stripeCustomerId;
    }
    if (stripeSubscriptionId != null) {
      payload['stripe_subscription_id'] = stripeSubscriptionId;
    }
    if (currentPeriodStart != null) {
      payload['current_period_start'] = currentPeriodStart
          .toUtc()
          .toIso8601String();
    }
    if (currentPeriodEnd != null) {
      payload['current_period_end'] = currentPeriodEnd
          .toUtc()
          .toIso8601String();
    }
    if (cancelAtPeriodEnd != null) {
      payload['cancel_at_period_end'] = cancelAtPeriodEnd;
    }
    return payload;
  }
}

DateTime _parseRequiredDate(dynamic value) {
  return _parseDate(value) ??
      DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is! String) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  return DateTime.tryParse(trimmed);
}
