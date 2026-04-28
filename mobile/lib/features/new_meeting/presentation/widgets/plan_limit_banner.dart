import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/upload_limits_provider.dart';

class PlanLimitBanner extends StatelessWidget {
  const PlanLimitBanner({
    required this.value,
    required this.onUpgrade,
    super.key,
  });

  final AsyncValue<UploadLimits> value;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (limits) {
        if (!limits.isAtDailyLimit) {
          return _PlanUsageBanner(limits: limits);
        }
        return _LimitReachedBanner(limits: limits, onUpgrade: onUpgrade);
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _PlanUsageBanner extends StatelessWidget {
  const _PlanUsageBanner({required this.limits});

  final UploadLimits limits;

  @override
  Widget build(BuildContext context) {
    final sessionsPerDay = limits.sessionsPerDay;
    final sessionText = sessionsPerDay == null
        ? 'Unlimited sessions today'
        : '${limits.sessionsToday}/$sessionsPerDay sessions today';
    final sizeText = limits.maxFileSizeMb == null
        ? 'Unlimited file size'
        : 'Max ${limits.maxFileSizeMb} MB';
    final durationText = limits.maxDurationMinutes == null
        ? 'Unlimited duration'
        : 'Max ${limits.maxDurationMinutes} min';

    return _BannerShell(
      icon: Icons.verified_outlined,
      color: AppColors.success,
      title: '${limits.label} plan',
      message: '$sessionText · $sizeText · $durationText',
    );
  }
}

class _LimitReachedBanner extends StatelessWidget {
  const _LimitReachedBanner({required this.limits, required this.onUpgrade});

  final UploadLimits limits;
  final VoidCallback onUpgrade;

  @override
  Widget build(BuildContext context) {
    return _BannerShell(
      icon: Icons.warning_amber_outlined,
      color: AppColors.warning,
      title: 'Daily upload limit reached',
      message:
          '${limits.label}: ${limits.sessionsToday}/${limits.sessionsPerDay} sessions used today.',
      action: TextButton(onPressed: onUpgrade, child: const Text('Upgrade')),
    );
  }
}

class _BannerShell extends StatelessWidget {
  const _BannerShell({
    required this.icon,
    required this.color,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[
            const SizedBox(width: AppSpacing.sm),
            action!,
          ],
        ],
      ),
    );
  }
}
