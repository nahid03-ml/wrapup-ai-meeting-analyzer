import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../subscription/data/subscription.dart';

class PlanStatusCard extends StatelessWidget {
  const PlanStatusCard({required this.subscription, super.key});

  final AsyncValue<Subscription?> subscription;

  @override
  Widget build(BuildContext context) {
    final state = subscription.when(
      data: (subscription) => _PlanState(
        tier: subscription?.planTier ?? PlanTier.free,
        loading: false,
      ),
      loading: () => const _PlanState(tier: PlanTier.free, loading: true),
      error: (error, stackTrace) =>
          const _PlanState(tier: PlanTier.free, loading: false),
    );

    final paid = state.tier != PlanTier.free;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: paid ? AppColors.brandGradient : null,
              color: paid ? null : AppColors.surfaceElevated,
              borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            ),
            child: Icon(
              paid ? Icons.workspace_premium_outlined : Icons.person_outline,
              color: paid ? Colors.white : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  state.loading
                      ? 'Checking plan...'
                      : '${_planLabel(state.tier)} plan',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  paid
                      ? 'Your workspace is active.'
                      : 'Upgrade options will arrive later.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanState {
  const _PlanState({required this.tier, required this.loading});

  final PlanTier tier;
  final bool loading;
}

String _planLabel(PlanTier tier) {
  return switch (tier) {
    PlanTier.free => 'Free',
    PlanTier.plus => 'Plus',
    PlanTier.business => 'Business',
    PlanTier.enterprise => 'Enterprise',
  };
}
