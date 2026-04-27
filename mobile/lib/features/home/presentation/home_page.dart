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
    final currentUser = ref.watch(currentUserProvider);
    final profileValue = ref.watch(currentProfileProvider);
    final meetingsValue = ref.watch(meetingsListProvider);
    final actionItemsValue = ref.watch(actionItemsProvider);
    final subscriptionValue = ref.watch(subscriptionProvider);

    final displayName = _displayName(
      fullName: profileValue.whenOrNull(data: (profile) => profile?.fullName),
      email: currentUser?.email,
    );

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
              GreetingHeader(
                displayName: displayName,
                subscription: subscriptionValue,
              ),
              const SizedBox(height: AppSpacing.lg),
              StatGrid(
                meetings:
                    meetingsValue.whenOrNull(data: (meetings) => meetings) ??
                    const [],
                actionItems:
                    actionItemsValue.whenOrNull(data: (items) => items) ??
                    const [],
              ),
              const SizedBox(height: AppSpacing.lg),
              RecentMeetingsSection(
                meetings: meetingsValue,
                onRetry: () => ref.invalidate(meetingsListProvider),
                onViewAll: () => context.go('/dashboard/meetings'),
                onOpenMeeting: (meeting) {
                  context.push('/dashboard/meetings/${meeting.id}');
                },
              ),
              const SizedBox(height: AppSpacing.lg),
              PendingTasksSection(
                actionItems: actionItemsValue,
                onRetry: () => ref.invalidate(actionItemsProvider),
                onViewAll: () => context.go('/dashboard/action-items'),
              ),
              const SizedBox(height: AppSpacing.lg),
              PlanStatusCard(subscription: subscriptionValue),
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
