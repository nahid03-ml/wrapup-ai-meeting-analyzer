import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../action_items/data/action_item.dart';

class PendingTasksSection extends StatelessWidget {
  const PendingTasksSection({
    required this.actionItems,
    required this.onRetry,
    required this.onViewAll,
    super.key,
  });

  final AsyncValue<List<ActionItem>> actionItems;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Pending Tasks',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: actionItems.when(
        loading: () => const _TaskSkeletonList(),
        error: (error, _) =>
            ErrorView(message: error.toString(), onRetry: onRetry),
        data: (items) {
          final visible = _latestPendingItems(items, 3);

          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.task_alt_outlined,
              title: 'No pending tasks',
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                _TaskTile(item: visible[index]),
                if (index != visible.length - 1)
                  const SizedBox(height: AppSpacing.md),
              ],
            ],
          );
        },
      ),
    );
  }
}

List<ActionItem> _latestPendingItems(List<ActionItem> items, int limit) {
  if (limit <= 0 || items.isEmpty) return const [];

  final visible = <ActionItem>[];
  for (final item in items) {
    if (item.isCompleted) continue;

    var inserted = false;
    for (var index = 0; index < visible.length; index++) {
      if (item.createdAt.isAfter(visible[index].createdAt)) {
        visible.insert(index, item);
        inserted = true;
        break;
      }
    }
    if (!inserted && visible.length < limit) {
      visible.add(item);
    }
    if (visible.length > limit) {
      visible.removeLast();
    }
  }

  return visible;
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({required this.item});

  final ActionItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: AppColors.warning,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title.isEmpty ? 'Untitled action item' : item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (item.assignedTo?.trim().isNotEmpty == true ||
                    item.deadline != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    children: [
                      if (item.assignedTo?.trim().isNotEmpty == true)
                        _MetaChip(
                          icon: Icons.person_outline,
                          label: item.assignedTo!.trim(),
                        ),
                      if (item.deadline != null)
                        _MetaChip(
                          icon: Icons.event_outlined,
                          label: DateFormat.yMMMd().format(
                            item.deadline!.toLocal(),
                          ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

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
          Icon(icon, size: 12, color: AppColors.textMuted),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSkeletonList extends StatelessWidget {
  const _TaskSkeletonList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(3, (index) {
        return Padding(
          padding: EdgeInsets.only(bottom: index == 2 ? 0 : AppSpacing.md),
          child: Container(
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.56),
              borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
              border: Border.all(
                color: AppColors.border.withValues(alpha: 0.72),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null)
                TextButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}
