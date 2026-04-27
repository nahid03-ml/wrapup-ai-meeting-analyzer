import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../meetings/data/meeting.dart';
import '../../../meetings/presentation/widgets/meeting_row.dart';
import '../../../meetings/presentation/widgets/meeting_skeleton.dart';

class RecentMeetingsSection extends StatelessWidget {
  const RecentMeetingsSection({
    required this.meetings,
    required this.onRetry,
    required this.onViewAll,
    required this.onOpenMeeting,
    super.key,
  });

  final AsyncValue<List<Meeting>> meetings;
  final VoidCallback onRetry;
  final VoidCallback onViewAll;
  final ValueChanged<Meeting> onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    return _SectionShell(
      title: 'Recent Meetings',
      actionLabel: 'View all',
      onAction: onViewAll,
      child: meetings.when(
        loading: () => const MeetingSkeleton(compact: true, count: 3),
        error: (error, _) =>
            ErrorView(message: error.toString(), onRetry: onRetry),
        data: (meetings) {
          final visible = _latestMeetings(meetings, 3);

          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.mic_none,
              title: 'No meetings yet',
              subtitle:
                  'Upload a recording or start an instant meeting to begin.',
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < visible.length; index++) ...[
                MeetingRow(
                  meeting: visible[index],
                  onTap: () => onOpenMeeting(visible[index]),
                ),
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

List<Meeting> _latestMeetings(List<Meeting> meetings, int limit) {
  if (limit <= 0 || meetings.isEmpty) return const [];

  final visible = <Meeting>[];
  for (final meeting in meetings) {
    var inserted = false;
    for (var index = 0; index < visible.length; index++) {
      if (meeting.createdAt.isAfter(visible[index].createdAt)) {
        visible.insert(index, meeting);
        inserted = true;
        break;
      }
    }
    if (!inserted && visible.length < limit) {
      visible.add(meeting);
    }
    if (visible.length > limit) {
      visible.removeLast();
    }
  }

  return visible;
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
