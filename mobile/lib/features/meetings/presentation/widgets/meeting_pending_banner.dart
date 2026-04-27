import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/session.dart';

class MeetingPendingBanner extends StatelessWidget {
  const MeetingPendingBanner({required this.sessions, super.key});

  final List<MeetingSession> sessions;

  @override
  Widget build(BuildContext context) {
    final session = _latestPendingSession(sessions);
    if (session == null) return const SizedBox.shrink();

    final progress = session.processingProgress?.clamp(0, 100);
    final message = session.processingMessage?.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hourglass_top, color: AppColors.warning),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Processing your meeting',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      message == null || message.isEmpty
                          ? 'Transcript and summary will update automatically.'
                          : message,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (progress != null) ...[
                const SizedBox(width: AppSpacing.md),
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
          if (progress != null) ...[
            const SizedBox(height: AppSpacing.md),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
              child: LinearProgressIndicator(
                minHeight: 5,
                value: progress / 100,
                color: AppColors.warning,
                backgroundColor: AppColors.warning.withValues(alpha: 0.18),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

MeetingSession? _latestPendingSession(List<MeetingSession> sessions) {
  final pending = sessions.where((session) => session.isPending).toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return pending.isEmpty ? null : pending.last;
}
