import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import 'stat_card.dart';

class StatGrid extends StatelessWidget {
  const StatGrid({
    required this.meetingsAnalyzed,
    required this.pendingActionItems,
    required this.meetingsThisWeek,
    super.key,
  });

  final int meetingsAnalyzed;
  final int pendingActionItems;
  final int meetingsThisWeek;

  @override
  Widget build(BuildContext context) {
    final cards = [
      StatCard(
        title: 'Meetings analyzed',
        value: meetingsAnalyzed.toString(),
        subtitle: 'Total meetings',
        icon: Icons.description_outlined,
        accentColor: AppColors.primary,
      ),
      StatCard(
        title: 'Action items',
        value: pendingActionItems.toString(),
        subtitle: 'Pending tasks',
        icon: Icons.task_alt_outlined,
        accentColor: AppColors.warning,
      ),
      StatCard(
        title: 'This week',
        value: meetingsThisWeek.toString(),
        subtitle: 'Meetings this week',
        icon: Icons.calendar_today_outlined,
        accentColor: AppColors.success,
      ),
      const StatCard(
        title: 'Transcript history',
        value: '7d',
        subtitle: 'Retention window',
        icon: Icons.history,
        accentColor: AppColors.cyan,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 340 ? 1 : 2;
        final spacing = AppSpacing.md * (columns - 1);
        final itemWidth = (constraints.maxWidth - spacing) / columns;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, height: 146, child: card),
          ],
        );
      },
    );
  }
}
