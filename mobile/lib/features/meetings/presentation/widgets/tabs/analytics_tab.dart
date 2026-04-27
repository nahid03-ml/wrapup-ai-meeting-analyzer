import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/theme/app_colors.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/widgets/async_value_widget.dart';
import '../../../../../core/widgets/empty_state.dart';
import '../../../../../core/widgets/error_view.dart';
import '../../../application/meeting_detail_provider.dart';
import '../../../data/session.dart';

class AnalyticsTab extends ConsumerWidget {
  const AnalyticsTab({required this.meetingId, super.key});

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
      data: (sessions) {
        final analytics = _latestSession(sessions)?.analyticsData;
        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(sessionsProvider(meetingId));
            await ref.read(sessionsProvider(meetingId).future);
          },
          child: _AnalyticsContent(analytics: analytics),
        );
      },
    );
  }
}

class _AnalyticsContent extends StatelessWidget {
  const _AnalyticsContent({required this.analytics});

  final Map<String, dynamic>? analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics == null || analytics!.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: const [
          Card(
            child: EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No analytics yet',
              subtitle:
                  'Engagement, sentiment, keywords, and speaker metrics will appear here.',
            ),
          ),
        ],
      );
    }

    final engagement = _numberFromKeys(analytics!, const [
      'engagement_score',
      'engagementScore',
      'engagement',
    ]);
    final sentiment = _stringFromKeys(analytics!, const [
      'sentiment',
      'overall_sentiment',
    ]);
    final keywords = _listFromKeys(analytics!, const [
      'keywords',
      'top_keywords',
      'key_points',
    ]);
    final speakers = _speakerContributions(
      _firstValue(analytics!, const [
        'speaker_contribution',
        'speakerContribution',
        'speaker_talk_time',
      ]),
    );

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        if (engagement != null)
          _MetricCard(
            title: 'Engagement',
            value: _formatEngagement(engagement),
            icon: Icons.trending_up,
          ),
        if (engagement != null) const SizedBox(height: AppSpacing.md),
        if (sentiment != null) _SentimentCard(sentiment: sentiment),
        if (sentiment != null) const SizedBox(height: AppSpacing.md),
        if (keywords.isNotEmpty) _KeywordsCard(keywords: keywords),
        if (keywords.isNotEmpty) const SizedBox(height: AppSpacing.md),
        if (speakers.isNotEmpty) _SpeakerBarsCard(speakers: speakers),
        if (engagement == null &&
            sentiment == null &&
            keywords.isEmpty &&
            speakers.isEmpty)
          const Card(
            child: EmptyState(
              icon: Icons.insights_outlined,
              title: 'No readable analytics yet',
              subtitle:
                  'Analytics exist, but this version does not recognize their shape yet.',
            ),
          ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 30),
          const SizedBox(width: AppSpacing.lg),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SentimentCard extends StatelessWidget {
  const _SentimentCard({required this.sentiment});

  final String sentiment;

  @override
  Widget build(BuildContext context) {
    final tone = sentiment.trim().toLowerCase();
    final color = tone.contains('pos')
        ? AppColors.success
        : tone.contains('neg') || tone.contains('tense')
        ? AppColors.destructive
        : AppColors.primary;
    final label = sentiment.trim().isEmpty ? 'Unknown' : sentiment.trim();

    return _GlassCard(
      child: Row(
        children: [
          Icon(Icons.mood_outlined, color: color),
          const SizedBox(width: AppSpacing.md),
          Text(
            'Sentiment',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              border: Border.all(color: color.withValues(alpha: 0.34)),
            ),
            child: Text(
              '${label[0].toUpperCase()}${label.substring(1)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KeywordsCard extends StatelessWidget {
  const _KeywordsCard({required this.keywords});

  final List<String> keywords;

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top keywords',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: keywords.take(12).map((keyword) {
              return Chip(
                label: Text(keyword),
                backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                side: BorderSide(
                  color: AppColors.primary.withValues(alpha: 0.26),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _SpeakerBarsCard extends StatelessWidget {
  const _SpeakerBarsCard({required this.speakers});

  final List<_SpeakerContribution> speakers;

  @override
  Widget build(BuildContext context) {
    final maxValue = speakers.fold<double>(
      0,
      (max, item) => item.value > max ? item.value : max,
    );

    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Speaker contribution',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final speaker in speakers) ...[
            _SpeakerBar(speaker: speaker, maxValue: maxValue),
            const SizedBox(height: AppSpacing.md),
          ],
        ],
      ),
    );
  }
}

class _SpeakerBar extends StatelessWidget {
  const _SpeakerBar({required this.speaker, required this.maxValue});

  final _SpeakerContribution speaker;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final pct = maxValue <= 0
        ? 0.0
        : (speaker.value / maxValue).clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                speaker.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            Text(
              _formatNumber(speaker.value),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
                Container(
                  width: constraints.maxWidth * pct,
                  height: 8,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  const _GlassCard({required this.child});

  final Widget child;

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
      child: child,
    );
  }
}

class _SpeakerContribution {
  const _SpeakerContribution({required this.label, required this.value});

  final String label;
  final double value;
}

MeetingSession? _latestSession(List<MeetingSession> sessions) {
  if (sessions.isEmpty) return null;
  final sorted = [...sessions]
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return sorted.last;
}

dynamic _firstValue(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    if (map.containsKey(key)) return map[key];
  }
  return null;
}

double? _numberFromKeys(Map<String, dynamic> map, List<String> keys) {
  final raw = _firstValue(map, keys);
  if (raw is num) return raw.toDouble();
  if (raw is String) return double.tryParse(raw.trim());
  return null;
}

String? _stringFromKeys(Map<String, dynamic> map, List<String> keys) {
  final raw = _firstValue(map, keys);
  if (raw is String && raw.trim().isNotEmpty) return raw.trim();
  if (raw is Map) {
    final label = raw['label'] ?? raw['value'] ?? raw['sentiment'];
    if (label is String && label.trim().isNotEmpty) return label.trim();
  }
  return null;
}

List<String> _listFromKeys(Map<String, dynamic> map, List<String> keys) {
  final raw = _firstValue(map, keys);
  if (raw is List) {
    return raw
        .map((item) => item is String ? item.trim() : item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
  }
  return const [];
}

List<_SpeakerContribution> _speakerContributions(dynamic raw) {
  if (raw is Map) {
    return raw.entries
        .map((entry) {
          final value = entry.value;
          final numeric = value is num
              ? value.toDouble()
              : value is String
              ? double.tryParse(value.trim())
              : null;
          if (numeric == null) return null;
          return _SpeakerContribution(
            label: entry.key.toString(),
            value: numeric,
          );
        })
        .whereType<_SpeakerContribution>()
        .toList();
  }

  if (raw is List) {
    return raw
        .map((item) {
          if (item is! Map) return null;
          final label = item['speaker'] ?? item['name'] ?? item['label'];
          final value =
              item['contribution'] ??
              item['talk_time'] ??
              item['talkTime'] ??
              item['seconds'] ??
              item['percentage'] ??
              item['value'];
          final numeric = value is num
              ? value.toDouble()
              : value is String
              ? double.tryParse(value.trim())
              : null;
          if (label == null || numeric == null) return null;
          return _SpeakerContribution(label: label.toString(), value: numeric);
        })
        .whereType<_SpeakerContribution>()
        .toList();
  }

  return const [];
}

String _formatEngagement(double value) {
  if (value <= 1) return '${(value * 100).round()}%';
  if (value <= 100) return '${value.round()}%';
  return _formatNumber(value);
}

String _formatNumber(double value) {
  if (value == value.roundToDouble()) return value.round().toString();
  return value.toStringAsFixed(1);
}
