import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../subscription/data/subscription.dart';

class PlanBadge extends StatelessWidget {
  const PlanBadge({required this.planTier, super.key});

  final PlanTier planTier;

  @override
  Widget build(BuildContext context) {
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
            planTierLabel(planTier),
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

String planTierLabel(PlanTier tier) {
  return switch (tier) {
    PlanTier.free => 'Free',
    PlanTier.plus => 'Plus',
    PlanTier.business => 'Business',
    PlanTier.enterprise => 'Enterprise',
  };
}

String planTierDescription(PlanTier tier) {
  return switch (tier) {
    PlanTier.free => 'Basic meeting memory access',
    PlanTier.plus => 'Expanded meeting intelligence',
    PlanTier.business => 'Team-ready meeting workflows',
    PlanTier.enterprise => 'Advanced workspace controls',
  };
}
