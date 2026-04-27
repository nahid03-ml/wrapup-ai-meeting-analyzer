import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../../action_items/application/action_items_provider.dart';
import '../../../../action_items/data/action_item.dart';
import '../../../../action_items/data/action_items_repository.dart';

class MeetingActionItemsTab extends ConsumerWidget {
  const MeetingActionItemsTab({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionItemsValue = ref.watch(actionItemsProvider);

    return AsyncValueWidget<List<ActionItem>>(
      value: actionItemsValue,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(actionItemsProvider),
      ),
      data: (items) {
        final meetingItems =
            items.where((item) => item.meetingId == meetingId).toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(actionItemsProvider);
            await ref.read(actionItemsProvider.future);
          },
          child: meetingItems.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  children: const [
                    Card(
                      child: EmptyState(
                        icon: Icons.task_alt_outlined,
                        title: 'No action items',
                        subtitle:
                            'Action items from this meeting will appear here.',
                      ),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: meetingItems.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final item = meetingItems[index];
                    return _ActionItemTile(
                      item: item,
                      onToggle: (value) {
                        unawaited(_toggleItem(context, ref, item, value));
                      },
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _toggleItem(
    BuildContext context,
    WidgetRef ref,
    ActionItem item,
    bool isCompleted,
  ) async {
    try {
      await ref
          .read(actionItemsRepositoryProvider)
          .toggle(item.id, isCompleted);
      ref.invalidate(actionItemsProvider);
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update action item: $error')),
      );
    }
  }
}

class _ActionItemTile extends StatelessWidget {
  const _ActionItemTile({required this.item, required this.onToggle});

  final ActionItem item;
  final ValueChanged<bool> onToggle;

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
          Checkbox(
            value: item.isCompleted,
            activeColor: AppColors.success,
            onChanged: (value) {
              if (value != null) onToggle(value);
            },
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.title.isEmpty ? 'Untitled action item' : item.title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: item.isCompleted
                        ? AppColors.textMuted
                        : AppColors.textPrimary,
                    decoration: item.isCompleted
                        ? TextDecoration.lineThrough
                        : null,
                    fontWeight: FontWeight.w700,
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
