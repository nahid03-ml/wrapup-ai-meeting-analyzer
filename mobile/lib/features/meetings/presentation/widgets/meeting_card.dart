import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/meeting.dart';
import 'processing_pill.dart';
import 'source_badge.dart';

class MeetingCard extends StatelessWidget {
  const MeetingCard({required this.meeting, this.onTap, super.key});

  final Meeting meeting;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final latestSession = meeting.latestSession;
    final title = _cleanTitle(meeting.title);
    final summaryPreview = _summaryPreview(latestSession?.summary);
    final language = _formatLanguage(latestSession?.languageDetected);
    final duration = _formatDuration(meeting.durationMinutes);
    final footerStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      color: AppColors.textSecondary,
      letterSpacing: 0,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        child: Ink(
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 196),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MeetingIcon(title: title),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SourceBadge(source: meeting.source),
                      ProcessingPill(
                        isProcessing: meeting.hasPendingSession,
                        progress: latestSession?.processingProgress,
                      ),
                    ],
                  ),
                  if (summaryPreview != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      summaryPreview,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.38,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _MetaItem(
                        icon: Icons.calendar_today_outlined,
                        label: _formatCreatedAt(meeting.createdAt),
                        style: footerStyle,
                      ),
                      _MetaItem(
                        icon: Icons.schedule,
                        label: duration,
                        style: footerStyle,
                      ),
                      if (language != null)
                        _MetaItem(
                          icon: Icons.language,
                          label: language,
                          style: footerStyle,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingIcon extends StatelessWidget {
  const _MeetingIcon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Text(
        _initial(title),
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({
    required this.icon,
    required this.label,
    required this.style,
  });

  final IconData icon;
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textMuted),
        const SizedBox(width: AppSpacing.xs),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
      ],
    );
  }
}

String _formatCreatedAt(DateTime value) {
  final local = value.toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(local.year, local.month, local.day);

  if (date == today) return 'Today';
  if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
  return DateFormat.yMMMd().format(local);
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

String _cleanTitle(String raw) {
  var title = raw.trim();
  if (title.isEmpty) return 'Untitled Meeting';

  final uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );
  if (uuid.hasMatch(title)) return 'Untitled Meeting';

  title = title
      .replaceFirst(
        RegExp(
          r'\.(mp3|mp4|m4a|wav|webm|ogg|flac|aac|mov|mkv)$',
          caseSensitive: false,
        ),
        '',
      )
      .replaceAll(RegExp(r'[_-]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  if (title.isEmpty || !RegExp('[a-zA-Z]').hasMatch(title)) {
    return 'Untitled Meeting';
  }

  return title
      .split(' ')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

String _initial(String title) {
  final match = RegExp('[a-zA-Z0-9]').firstMatch(title);
  return match == null ? 'M' : match.group(0)!.toUpperCase();
}
