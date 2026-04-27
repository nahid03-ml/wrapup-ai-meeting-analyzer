import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/action_item.dart';

class ActionItemTile extends StatelessWidget {
  const ActionItemTile({
    required this.item,
    required this.onToggle,
    this.meetingTitle,
    this.isBusy = false,
    super.key,
  });

  final ActionItem item;
  final ValueChanged<bool> onToggle;
  final String? meetingTitle;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final title = item.title.trim().isEmpty ? 'Untitled task' : item.title;
    final isOverdue = _isOverdue(item);
    final isDueSoon = _isDueSoon(item);

    return AnimatedOpacity(
      opacity: isBusy ? 0.64 : 1,
      duration: const Duration(milliseconds: 160),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.56),
          borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
          border: Border.all(
            color: isOverdue
                ? AppColors.destructive.withValues(alpha: 0.5)
                : AppColors.border.withValues(alpha: 0.72),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: item.isCompleted,
              activeColor: AppColors.success,
              side: BorderSide(
                color: isOverdue ? AppColors.destructive : AppColors.border,
              ),
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value != null) onToggle(value);
                    },
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                color: item.isCompleted
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                                decoration: item.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _StatusPill(isCompleted: item.isCompleted),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (meetingTitle?.trim().isNotEmpty == true)
                        _MetaChip(
                          icon: Icons.description_outlined,
                          label: meetingTitle!.trim(),
                        ),
                      if (item.assignedTo?.trim().isNotEmpty == true)
                        _MetaChip(
                          icon: Icons.person_outline,
                          label: item.assignedTo!.trim(),
                        ),
                      if (item.deadline != null)
                        _MetaChip(
                          icon: isOverdue
                              ? Icons.warning_amber_rounded
                              : Icons.event_outlined,
                          label: DateFormat.yMMMd().format(
                            item.deadline!.toLocal(),
                          ),
                          color: isOverdue
                              ? AppColors.destructive
                              : isDueSoon
                              ? AppColors.warning
                              : AppColors.textMuted,
                        ),
                      if (item.deadline == null &&
                          meetingTitle?.trim().isNotEmpty != true)
                        const _MetaChip(
                          icon: Icons.description_outlined,
                          label: 'Meeting',
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final color = isCompleted ? AppColors.success : AppColors.warning;
    final label = isCompleted ? 'Completed' : 'Pending';
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: color.withValues(alpha: 0.38)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color = AppColors.textMuted,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isOverdue(ActionItem item) {
  final deadline = item.deadline;
  if (deadline == null || item.isCompleted) return false;
  return deadline.toLocal().isBefore(DateTime.now());
}

bool _isDueSoon(ActionItem item) {
  final deadline = item.deadline;
  if (deadline == null || item.isCompleted) return false;
  final localDeadline = deadline.toLocal();
  final now = DateTime.now();
  return !localDeadline.isBefore(now) &&
      !localDeadline.isAfter(now.add(const Duration(days: 7)));
}
