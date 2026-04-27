import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/meeting.dart';
import '../../data/session.dart';
import 'processing_pill.dart';
import 'source_badge.dart';

class MeetingDetailHeader extends StatelessWidget {
  const MeetingDetailHeader({
    required this.meeting,
    required this.sessions,
    super.key,
  });

  final Meeting meeting;
  final List<MeetingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final latestSession = _latestSession(sessions) ?? meeting.latestSession;
    final hasPending =
        meeting.hasPendingSession ||
        sessions.any((session) => session.isPending);
    final language = _formatLanguage(latestSession?.languageDetected);
    final summary = _summaryPreview(latestSession?.summary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _displayTitle(meeting.title),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SourceBadge(source: meeting.source),
              ProcessingPill(
                isProcessing: hasPending,
                progress: latestSession?.processingProgress,
              ),
              if (language != null)
                _InfoPill(icon: Icons.language, label: language),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.sm,
            children: [
              _MetaItem(
                icon: Icons.calendar_today_outlined,
                label: DateFormat.yMMMd().add_jm().format(
                  meeting.createdAt.toLocal(),
                ),
              ),
              _MetaItem(
                icon: Icons.schedule,
                label: _formatDuration(meeting.durationMinutes),
              ),
            ],
          ),
          if (summary != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              summary,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

MeetingSession? _latestSession(List<MeetingSession> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted.last;
}

String _displayTitle(String raw) {
  final trimmed = raw.trim();
  return trimmed.isEmpty ? 'Untitled Meeting' : trimmed;
}

String _formatDuration(int? minutes) {
  if (minutes == null) return '—';
  if (minutes < 60) return '${minutes}m';
  final hours = minutes ~/ 60;
  final remainder = minutes % 60;
  return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
}

String? _summaryPreview(Map<String, dynamic>? summary) {
  if (summary == null) return null;
  for (final key in const ['overview', 'summary', 'executive_summary']) {
    final value = summary[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String? _formatLanguage(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  final lower = trimmed.toLowerCase();
  const known = {
    'en': 'English',
    'en-us': 'English',
    'en-gb': 'English',
    'bn': 'Bengali',
    'bn-bd': 'Bengali',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'hi': 'Hindi',
    'ar': 'Arabic',
    'zh': 'Chinese',
    'ja': 'Japanese',
    'pt': 'Portuguese',
    'ru': 'Russian',
  };
  if (known.containsKey(lower)) return known[lower];
  if (lower.contains('mixed') || lower.contains('multi')) return 'Mixed';
  return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
}
