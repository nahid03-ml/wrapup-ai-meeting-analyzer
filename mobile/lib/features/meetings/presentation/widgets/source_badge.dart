import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class SourceBadge extends StatelessWidget {
  const SourceBadge({required this.source, super.key});

  final String? source;

  @override
  Widget build(BuildContext context) {
    final style = _sourceStyle(source);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: style.color,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: style.color.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(style.icon, size: 12, color: style.color),
          const SizedBox(width: AppSpacing.xs),
          Text(style.label, style: textStyle),
        ],
      ),
    );
  }
}

_SourceBadgeStyle _sourceStyle(String? source) {
  switch (source?.trim().toLowerCase()) {
    case 'recorded':
      return const _SourceBadgeStyle(
        label: 'Recorded',
        icon: Icons.mic_none,
        color: AppColors.primary,
      );
    case 'uploaded':
      return const _SourceBadgeStyle(
        label: 'Uploaded',
        icon: Icons.cloud_upload_outlined,
        color: AppColors.cyan,
      );
    case 'live':
      return const _SourceBadgeStyle(
        label: 'Live',
        icon: Icons.graphic_eq,
        color: AppColors.success,
      );
    default:
      return const _SourceBadgeStyle(
        label: 'Meeting',
        icon: Icons.description_outlined,
        color: AppColors.textMuted,
      );
  }
}

class _SourceBadgeStyle {
  const _SourceBadgeStyle({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}
