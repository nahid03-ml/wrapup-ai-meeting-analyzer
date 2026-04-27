import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../subscription/data/subscription.dart';

class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.displayName,
    required this.subscription,
    super.key,
  });

  final String displayName;
  final AsyncValue<Subscription?> subscription;

  @override
  Widget build(BuildContext context) {
    final planTier = subscription.whenOrNull(
      data: (subscription) => subscription?.planTier ?? PlanTier.free,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Dashboard',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (planTier != null) _PlanBadge(planTier: planTier),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Welcome back, $displayName 👋',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge({required this.planTier});

  final PlanTier planTier;

  @override
  Widget build(BuildContext context) {
    final label = _planLabel(planTier);
    final paid = planTier != PlanTier.free;
    final color = paid ? AppColors.warning : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.workspace_premium_outlined : Icons.person_outline,
            size: 13,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

String _planLabel(PlanTier tier) {
  return switch (tier) {
    PlanTier.free => 'Free',
    PlanTier.plus => 'Plus',
    PlanTier.business => 'Business',
    PlanTier.enterprise => 'Enterprise',
  };
}
