import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/upload_progress.dart';

class UploadProgressIndicator extends StatelessWidget {
  const UploadProgressIndicator({
    required this.progress,
    this.onRetry,
    super.key,
  });

  final UploadProgress progress;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (progress.stage == UploadStage.idle) {
      return const SizedBox.shrink();
    }

    final isFailed = progress is UploadFailed;
    final isDone = progress is UploadDone;
    final color = isFailed
        ? AppColors.destructive
        : isDone
        ? AppColors.success
        : AppColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: color.withValues(alpha: 0.34)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconFor(progress.stage), color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  _messageFor(progress),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (progress.isWorking) ...[
            const SizedBox(height: AppSpacing.md),
            const LinearProgressIndicator(),
          ],
          if (isFailed && onRetry != null) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              _failureDetail(progress),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

String _messageFor(UploadProgress progress) {
  return switch (progress.stage) {
    UploadStage.validating => 'Checking file and account limits...',
    UploadStage.creatingMeeting => 'Creating meeting...',
    UploadStage.uploadingFile => 'Uploading recording...',
    UploadStage.creatingSession => 'Creating processing session...',
    UploadStage.enqueuingProcessing => 'Starting AI processing...',
    UploadStage.done => 'Upload complete.',
    UploadStage.failed => progress.message ?? 'Upload failed.',
    UploadStage.idle => '',
  };
}

String _failureDetail(UploadProgress progress) {
  if (progress.meetingId != null && progress.sessionId != null) {
    return 'File uploaded, but processing could not start. You can open the meeting and retry later.';
  }
  return 'Your selected file, title, and language are still here.';
}

IconData _iconFor(UploadStage stage) {
  return switch (stage) {
    UploadStage.done => Icons.check_circle_outline,
    UploadStage.failed => Icons.error_outline,
    UploadStage.uploadingFile => Icons.cloud_upload_outlined,
    UploadStage.enqueuingProcessing => Icons.auto_awesome_outlined,
    _ => Icons.hourglass_top_outlined,
  };
}
