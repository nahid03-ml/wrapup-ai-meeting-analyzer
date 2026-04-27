import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum ActionItemsFilter { all, pending, completed, assigned, overdue, dueSoon }

extension ActionItemsFilterLabel on ActionItemsFilter {
  String get label {
    return switch (this) {
      ActionItemsFilter.all => 'All',
      ActionItemsFilter.pending => 'Pending',
      ActionItemsFilter.completed => 'Completed',
      ActionItemsFilter.assigned => 'Assigned',
      ActionItemsFilter.overdue => 'Overdue',
      ActionItemsFilter.dueSoon => 'Due Soon',
    };
  }
}

class ActionItemsFilterChips extends StatelessWidget {
  const ActionItemsFilterChips({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final ActionItemsFilter selected;
  final ValueChanged<ActionItemsFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: ActionItemsFilter.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = ActionItemsFilter.values[index];
          final isSelected = filter == selected;
          return ChoiceChip(
            selected: isSelected,
            label: Text(filter.label),
            showCheckmark: false,
            onSelected: (_) => onChanged(filter),
            backgroundColor: AppColors.surface.withValues(alpha: 0.42),
            selectedColor: AppColors.primary.withValues(alpha: 0.22),
            side: BorderSide(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.54)
                  : AppColors.border.withValues(alpha: 0.72),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
            ),
            labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isSelected
                  ? AppColors.textPrimary
                  : AppColors.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              letterSpacing: 0,
            ),
          );
        },
      ),
    );
  }
}
