import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

enum MeetingFilter { all, mine, recorded, uploaded, live, shared }

extension MeetingFilterLabel on MeetingFilter {
  String get label {
    return switch (this) {
      MeetingFilter.all => 'All',
      MeetingFilter.mine => 'Mine',
      MeetingFilter.recorded => 'Recorded',
      MeetingFilter.uploaded => 'Uploaded',
      MeetingFilter.live => 'Live',
      MeetingFilter.shared => 'Shared',
    };
  }
}

class MeetingFilterChips extends StatelessWidget {
  const MeetingFilterChips({
    required this.selected,
    required this.onChanged,
    super.key,
  });

  final MeetingFilter selected;
  final ValueChanged<MeetingFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        itemCount: MeetingFilter.values.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, index) {
          final filter = MeetingFilter.values[index];
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
