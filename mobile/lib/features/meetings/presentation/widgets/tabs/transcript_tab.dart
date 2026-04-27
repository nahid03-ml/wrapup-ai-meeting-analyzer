import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../application/meeting_detail_provider.dart';
import '../../../data/session.dart';

class TranscriptTab extends ConsumerWidget {
  const TranscriptTab({required this.meetingId, super.key});

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
        child: _TranscriptContent(session: _latestSession(sessions)),
      ),
    );
  }
}

class _TranscriptContent extends StatelessWidget {
  const _TranscriptContent({required this.session});

  final MeetingSession? session;

  @override
  Widget build(BuildContext context) {
    if (session?.isPending ?? false) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [_ProcessingTranscriptCard(session: session!)],
      );
    }

    final transcript = session?.transcript?.trim();
    if (transcript == null || transcript.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Card(
            child: EmptyState(
              icon: Icons.article_outlined,
              title: 'No transcript yet',
              subtitle: 'Transcript text will appear here after processing.',
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.56),
            borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
          ),
          child: _TranscriptText(transcript: transcript),
        ),
      ],
    );
  }
}

class _ProcessingTranscriptCard extends StatelessWidget {
  const _ProcessingTranscriptCard({required this.session});

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
          const Icon(Icons.hourglass_top, color: AppColors.warning, size: 34),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Processing your meeting...',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            session.processingMessage?.trim().isNotEmpty == true
                ? session.processingMessage!.trim()
                : 'Transcript and summary will update automatically.',
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

class _TranscriptText extends StatelessWidget {
  const _TranscriptText({required this.transcript});

  final String transcript;

  @override
  Widget build(BuildContext context) {
    final lines = transcript
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();

    if (lines.isEmpty) {
      return SelectableText(
        transcript,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppColors.textPrimary,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines) ...[
          SelectableText.rich(
            _speakerTextSpan(context, line),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

TextSpan _speakerTextSpan(BuildContext context, String line) {
  final style = Theme.of(
    context,
  ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary, height: 1.5);
  final speakerStyle = style?.copyWith(
    color: AppColors.primary,
    fontWeight: FontWeight.w800,
  );

  final match = RegExp(
    r'^(\[[^\]]+\]\s*)?(Speaker(?:\s+\d+)?)\s*:\s*(.+)$',
    caseSensitive: false,
  ).firstMatch(line);

  if (match == null) {
    return TextSpan(text: line, style: style);
  }

  final timestamp = match.group(1) ?? '';
  final speaker = match.group(2) ?? 'Speaker';
  final text = match.group(3) ?? '';
  return TextSpan(
    style: style,
    children: [
      if (timestamp.isNotEmpty)
        TextSpan(
          text: timestamp,
          style: style?.copyWith(color: AppColors.textMuted),
        ),
      TextSpan(text: '$speaker: ', style: speakerStyle),
      TextSpan(text: text),
    ],
  );
}

MeetingSession? _latestSession(List<MeetingSession> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted.last;
}
