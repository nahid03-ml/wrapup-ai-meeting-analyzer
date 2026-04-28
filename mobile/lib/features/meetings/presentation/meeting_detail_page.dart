import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/async_value_widget.dart';
import '../../../core/widgets/error_view.dart';
import '../application/meeting_detail_provider.dart';
import '../data/meeting.dart';
import '../data/session.dart';
import 'widgets/audio_player_section.dart';
import 'widgets/meeting_detail_header.dart';
import 'widgets/meeting_pending_banner.dart';
import 'widgets/meeting_skeleton.dart';
import 'widgets/tabs/analytics_tab.dart';
import 'widgets/tabs/ask_ai_tab.dart';
import 'widgets/tabs/meeting_action_items_tab.dart';
import 'widgets/tabs/notes_tab.dart';
import 'widgets/tabs/summary_tab.dart';
import 'widgets/tabs/transcript_tab.dart';

class MeetingDetailPage extends ConsumerWidget {
  const MeetingDetailPage({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meetingValue = ref.watch(meetingProvider(meetingId));
    final sessionsValue = ref.watch(sessionsProvider(meetingId));
    final title = meetingValue.maybeWhen(
      data: (meeting) => _displayTitle(meeting),
      orElse: () => 'Meeting Detail',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<_DeferredAction>(
            tooltip: 'Meeting actions',
            onSelected: (action) => _showDeferredSnackBar(context),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _DeferredAction.share,
                child: _DeferredActionItem(
                  icon: Icons.ios_share_outlined,
                  label: 'Share',
                ),
              ),
              PopupMenuItem(
                value: _DeferredAction.exportPdf,
                child: _DeferredActionItem(
                  icon: Icons.picture_as_pdf_outlined,
                  label: 'Export PDF',
                ),
              ),
              PopupMenuItem(
                value: _DeferredAction.delete,
                child: _DeferredActionItem(
                  icon: Icons.delete_outline,
                  label: 'Delete',
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: AsyncValueWidget<Meeting>(
          value: meetingValue,
          loading: () => const _MeetingDetailLoading(),
          error: (error, _) => ErrorView(
            message: error.toString(),
            onRetry: () => ref.invalidate(meetingProvider(meetingId)),
          ),
          data: (meeting) {
            final sessions =
                sessionsValue.whenOrNull(data: (sessions) => sessions) ??
                meeting.sessions;
            return _MeetingDetailBody(
              meetingId: meetingId,
              meeting: meeting,
              sessions: sessions,
            );
          },
        ),
      ),
    );
  }
}

class _MeetingDetailBody extends StatelessWidget {
  const _MeetingDetailBody({
    required this.meetingId,
    required this.meeting,
    required this.sessions,
  });

  final String meetingId;
  final Meeting meeting;
  final List<MeetingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final currentSession = _currentSession(sessions);

    return DefaultTabController(
      length: 6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MeetingPendingBanner(sessions: sessions),
                if (sessions.any((session) => session.isPending))
                  const SizedBox(height: AppSpacing.md),
                MeetingDetailHeader(meeting: meeting, sessions: sessions),
                if (currentSession?.audioFileUrl?.trim().isNotEmpty ==
                    true) ...[
                  const SizedBox(height: AppSpacing.md),
                  AudioPlayerSection(session: currentSession!),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Transcript', icon: Icon(Icons.article_outlined)),
              Tab(text: 'Summary', icon: Icon(Icons.summarize_outlined)),
              Tab(text: 'Actions', icon: Icon(Icons.task_alt_outlined)),
              Tab(text: 'Analytics', icon: Icon(Icons.bar_chart_outlined)),
              Tab(text: 'Ask AI', icon: Icon(Icons.smart_toy_outlined)),
              Tab(text: 'Notes', icon: Icon(Icons.sticky_note_2_outlined)),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                TranscriptTab(meetingId: meetingId),
                SummaryTab(meetingId: meetingId),
                MeetingActionItemsTab(meetingId: meetingId),
                AnalyticsTab(meetingId: meetingId),
                AskAiTab(meetingId: meetingId),
                NotesTab(meetingId: meetingId),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingDetailLoading extends StatelessWidget {
  const _MeetingDetailLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: const [
        MeetingSkeleton(count: 1),
        SizedBox(height: AppSpacing.lg),
        MeetingSkeleton(count: 3),
      ],
    );
  }
}

class _DeferredActionItem extends StatelessWidget {
  const _DeferredActionItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: AppSpacing.md),
        Text(label),
      ],
    );
  }
}

enum _DeferredAction { share, exportPdf, delete }

void _showDeferredSnackBar(BuildContext context) {
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Coming in Phase 9')));
}

String _displayTitle(Meeting meeting) {
  final trimmed = meeting.title.trim();
  return trimmed.isEmpty ? 'Untitled Meeting' : trimmed;
}

MeetingSession? _currentSession(List<MeetingSession> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted.last;
}
