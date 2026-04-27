import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_spacing.dart';
import '../../action_items/application/action_items_provider.dart';
import '../../meetings/application/meetings_provider.dart';
import '../../profile/application/profile_provider.dart';
import '../../subscription/application/subscription_provider.dart';
import 'widgets/greeting_header.dart';
import 'widgets/pending_tasks_section.dart';
import 'widgets/plan_status_card.dart';
import 'widgets/recent_meetings_section.dart';
import 'widgets/stat_grid.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('WrapUp AI')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              const _GreetingSection(),
              const SizedBox(height: AppSpacing.lg),
              const _StatsSection(),
              const SizedBox(height: AppSpacing.lg),
              const _RecentMeetingsDashboardSection(),
              const SizedBox(height: AppSpacing.lg),
              const _PendingTasksDashboardSection(),
              const SizedBox(height: AppSpacing.lg),
              const _PlanStatusSection(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(meetingsListProvider)
      ..invalidate(actionItemsProvider)
      ..invalidate(subscriptionProvider)
      ..invalidate(currentProfileProvider);

    await Future.wait([
      _readSafely(() => ref.read(meetingsListProvider.future)),
      _readSafely(() => ref.read(actionItemsProvider.future)),
      _readSafely(() => ref.read(subscriptionProvider.future)),
      _readSafely(() => ref.read(currentProfileProvider.future)),
    ]);
  }
}

class _GreetingSection extends ConsumerWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(currentUserProvider.select((user) => user?.email));
    final profileValue = ref.watch(currentProfileProvider);
    final subscriptionValue = ref.watch(subscriptionProvider);

    final displayName = _displayName(
      fullName: profileValue.whenOrNull(data: (profile) => profile?.fullName),
      email: email,
    );

    return GreetingHeader(
      displayName: displayName,
      subscription: subscriptionValue,
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsValue = ref.watch(meetingsListProvider);
    final actionItemsValue = ref.watch(actionItemsProvider);
    final meetings =
        meetingsValue.whenOrNull(data: (meetings) => meetings) ?? const [];
    final actionItems =
        actionItemsValue.whenOrNull(data: (items) => items) ?? const [];

    return StatGrid(
      meetingsAnalyzed: meetings.length,
      pendingActionItems: actionItems.where((item) => !item.isCompleted).length,
      meetingsThisWeek: meetings
          .where((meeting) => _isInCurrentWeek(meeting.createdAt))
          .length,
    );
  }
}

class _RecentMeetingsDashboardSection extends ConsumerWidget {
  const _RecentMeetingsDashboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingsValue = ref.watch(meetingsListProvider);

    return RecentMeetingsSection(
      meetings: meetingsValue,
      onRetry: () => ref.invalidate(meetingsListProvider),
      onViewAll: () => context.go('/dashboard/meetings'),
      onOpenMeeting: (meeting) {
        context.push('/dashboard/meetings/${meeting.id}');
      },
    );
  }
}

class _PendingTasksDashboardSection extends ConsumerWidget {
  const _PendingTasksDashboardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actionItemsValue = ref.watch(actionItemsProvider);

    return PendingTasksSection(
      actionItems: actionItemsValue,
      onRetry: () => ref.invalidate(actionItemsProvider),
      onViewAll: () => context.go('/dashboard/action-items'),
    );
  }
}

class _PlanStatusSection extends ConsumerWidget {
  const _PlanStatusSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PlanStatusCard(subscription: ref.watch(subscriptionProvider));
  }
}

Future<void> _readSafely<T>(Future<T> Function() read) async {
  try {
    await read();
  } catch (_) {
    // Individual sections render their own error states.
  }
}

String _displayName({String? fullName, String? email}) {
  final name = fullName?.trim();
  if (name != null && name.isNotEmpty) return name;

  final rawEmail = email?.trim();
  if (rawEmail != null && rawEmail.isNotEmpty) {
    final local = rawEmail.split('@').first.trim();
    if (local.isNotEmpty) return local;
  }

  return 'there';
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
