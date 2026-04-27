import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../application/meeting_detail_provider.dart';
import '../../../data/session.dart';

class SummaryTab extends ConsumerWidget {
  const SummaryTab({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsValue = ref.watch(sessionsProvider(meetingId));

    return AsyncValueWidget<List<MeetingSession>>(
      value: sessionsValue,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, _) => ErrorView(
        message: error.toString(),
        onRetry: () => ref.invalidate(sessionsProvider(meetingId)),
      ),
      data: (sessions) => RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(sessionsProvider(meetingId));
          await ref.read(sessionsProvider(meetingId).future);
        },
        child: _SummaryContent(session: _latestSession(sessions)),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.session});

  final MeetingSession? session;

  @override
  Widget build(BuildContext context) {
    if (session?.isPending ?? false) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [_ProcessingSummaryCard(session: session!)],
      );
    }

    final summary = session?.summary;
    if (summary == null || summary.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Card(
            child: EmptyState(
              icon: Icons.summarize_outlined,
              title: 'No summary yet',
              subtitle: 'Meeting summary will appear here after processing.',
            ),
          ),
        ],
      );
    }

    final sections = _summarySections(summary);
    if (sections.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Card(
            child: EmptyState(
              icon: Icons.summarize_outlined,
              title: 'No readable summary yet',
              subtitle:
                  'A summary exists, but this version does not recognize its shape yet.',
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemBuilder: (context, index) => _SummarySectionCard(
        title: sections[index].title,
        value: sections[index].value,
      ),
      separatorBuilder: (context, index) =>
          const SizedBox(height: AppSpacing.md),
      itemCount: sections.length,
    );
  }
}

class _ProcessingSummaryCard extends StatelessWidget {
  const _ProcessingSummaryCard({required this.session});

  final MeetingSession session;

  @override
  Widget build(BuildContext context) {
    final progress = session.processingProgress?.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.warning, size: 34),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Summary is being generated',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            session.processingMessage?.trim().isNotEmpty == true
                ? session.processingMessage!.trim()
                : 'This will update automatically after processing.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.xl),
            LinearProgressIndicator(
              value: progress / 100,
              color: AppColors.warning,
              backgroundColor: AppColors.warning.withValues(alpha: 0.18),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$progress%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummarySectionCard extends StatelessWidget {
  const _SummarySectionCard({required this.title, required this.value});

  final String title;
  final dynamic value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.56),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SummaryValue(value: value),
        ],
      ),
    );
  }
}

class _SummaryValue extends StatelessWidget {
  const _SummaryValue({required this.value, this.depth = 0});

  final dynamic value;
  final int depth;

  @override
  Widget build(BuildContext context) {
    if (value is String) {
      return _Paragraph(text: value as String);
    }

    if (value is num || value is bool) {
      return _Paragraph(text: value.toString());
    }

    if (value is List) {
      final items = (value as List)
          .where(_hasReadableContent)
          .take(40)
          .toList(growable: false);
      if (items.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in items) ...[
            _BulletItem(value: item, depth: depth),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    if (value is Map) {
      final entries = (value as Map).entries
          .where((entry) => _hasReadableContent(entry.value))
          .toList(growable: false);
      if (entries.isEmpty) return const SizedBox.shrink();

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in entries) ...[
            _KeyValueBlock(
              label: _readableLabel(entry.key.toString()),
              value: entry.value,
              depth: depth,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      );
    }

    return _Paragraph(text: value.toString());
  }
}

class _BulletItem extends StatelessWidget {
  const _BulletItem({required this.value, required this.depth});

  final dynamic value;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Icon(
            Icons.circle,
            size: 6,
            color: depth > 0 ? AppColors.textMuted : AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _SummaryValue(value: value, depth: depth + 1),
        ),
      ],
    );
  }
}

class _KeyValueBlock extends StatelessWidget {
  const _KeyValueBlock({
    required this.label,
    required this.value,
    required this.depth,
  });

  final String label;
  final dynamic value;
  final int depth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: depth > 0 ? AppColors.textSecondary : AppColors.primary,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _SummaryValue(value: value, depth: depth + 1),
      ],
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      text.trim(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: AppColors.textSecondary,
        height: 1.45,
      ),
    );
  }
}

class _SummarySection {
  const _SummarySection({required this.title, required this.value});

  final String title;
  final dynamic value;
}

List<_SummarySection> _summarySections(Map<String, dynamic> summary) {
  final sections = <_SummarySection>[];
  final consumed = <String>{};

  void add(String title, List<String> keys) {
    for (final key in keys) {
      final value = summary[key];
      if (!_hasReadableContent(value)) continue;
      sections.add(_SummarySection(title: title, value: value));
      consumed.add(key);
      return;
    }
  }

  add('Executive Summary', const [
    'executive_summary',
    'executiveSummary',
    'overview',
    'summary',
  ]);
  add('Key Points', const ['key_points', 'keyPoints']);
  add('Decisions', const ['decisions']);
  add('Follow-ups', const ['follow_ups', 'followUps']);
  add('Action Items', const ['action_items', 'actionItems']);
  add('Structured MOM', const ['structured_mom', 'structuredMom', 'mom']);
  add('Agenda', const ['agenda']);
  add('Discussion', const ['discussion']);
  add('Next Steps', const ['next_steps', 'nextSteps']);
  add('Speaker Contribution', const [
    'speaker_contribution',
    'speakerContribution',
    'speaker_breakdown',
    'speakerBreakdown',
  ]);

  if (sections.isNotEmpty) return sections;

  for (final entry in summary.entries) {
    if (consumed.contains(entry.key) || !_hasReadableContent(entry.value)) {
      continue;
    }
    sections.add(
      _SummarySection(title: _readableLabel(entry.key), value: entry.value),
    );
  }

  return sections;
}

bool _hasReadableContent(dynamic value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is List) return value.any(_hasReadableContent);
  if (value is Map) return value.values.any(_hasReadableContent);
  return true;
}

String _readableLabel(String key) {
  final withSpaces = key
      .replaceAll('_', ' ')
      .replaceAllMapped(
        RegExp(r'([a-z])([A-Z])'),
        (match) => '${match.group(1)} ${match.group(2)}',
      )
      .trim();

  if (withSpaces.isEmpty) return 'Details';

  return withSpaces
      .split(RegExp(r'\s+'))
      .map((word) {
        final lower = word.toLowerCase();
        if (lower == 'mom') return 'MOM';
        return '${lower[0].toUpperCase()}${lower.substring(1)}';
      })
      .join(' ');
}

MeetingSession? _latestSession(List<MeetingSession> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted.last;
}
