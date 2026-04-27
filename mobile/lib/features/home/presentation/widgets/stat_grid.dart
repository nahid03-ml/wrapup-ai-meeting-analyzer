import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../action_items/data/action_item.dart';
import '../../../meetings/data/meeting.dart';
import 'stat_card.dart';

class StatGrid extends StatelessWidget {
  const StatGrid({
    required this.meetings,
    required this.actionItems,
    super.key,
  });

  final List<Meeting> meetings;
  final List<ActionItem> actionItems;

  @override
  Widget build(BuildContext context) {
    final incompleteTasks = actionItems
        .where((item) => !item.isCompleted)
        .length;
    final thisWeek = meetings
        .where((meeting) => _isInCurrentWeek(meeting.createdAt))
        .length;

    final cards = [
      StatCard(
        title: 'Meetings analyzed',
        value: meetings.length.toString(),
        subtitle: 'Total meetings',
        icon: Icons.description_outlined,
        accentColor: AppColors.primary,
      ),
      StatCard(
        title: 'Action items',
        value: incompleteTasks.toString(),
        subtitle: 'Pending tasks',
        icon: Icons.task_alt_outlined,
        accentColor: AppColors.warning,
      ),
      StatCard(
        title: 'This week',
        value: thisWeek.toString(),
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

bool _isInCurrentWeek(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final monday = today.subtract(
    Duration(days: today.weekday - DateTime.monday),
  );
  final nextMonday = monday.add(const Duration(days: 7));
  return !local.isBefore(monday) && local.isBefore(nextMonday);
}
