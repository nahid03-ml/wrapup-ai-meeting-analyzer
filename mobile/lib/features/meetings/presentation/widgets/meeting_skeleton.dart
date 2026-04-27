import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class MeetingSkeleton extends StatelessWidget {
  const MeetingSkeleton({this.compact = false, this.count = 3, super.key});

  final bool compact;
  final int count;

  @override
  Widget build(BuildContext context) {
    final itemCount = count < 0 ? 0 : count;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(itemCount, (index) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == itemCount - 1 ? 0 : AppSpacing.md,
          ),
          child: _SkeletonCard(compact: compact),
        );
      }),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          _SkeletonBox(
            width: compact ? 36 : 44,
            height: compact ? 36 : 44,
            radius: AppSpacing.radiusMd,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const FractionallySizedBox(
                  widthFactor: 0.62,
                  child: _SkeletonBox(height: 14),
                ),
                const SizedBox(height: AppSpacing.sm),
                FractionallySizedBox(
                  widthFactor: compact ? 0.44 : 0.82,
                  child: const _SkeletonBox(height: 11),
                ),
                if (!compact) ...[
                  const SizedBox(height: AppSpacing.md),
                  const Row(
                    children: [
                      _SkeletonBox(
                        width: 72,
                        height: 20,
                        radius: AppSpacing.radiusFull,
                      ),
                      SizedBox(width: AppSpacing.sm),
                      _SkeletonBox(
                        width: 86,
                        height: 20,
                        radius: AppSpacing.radiusFull,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    this.width,
    required this.height,
    this.radius = AppSpacing.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.45)),
      ),
    );
  }
}
