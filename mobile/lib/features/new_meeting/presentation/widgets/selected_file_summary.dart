import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/upload_repository.dart';

class SelectedFileSummary extends StatelessWidget {
  const SelectedFileSummary({
    required this.file,
    required this.sizeBytes,
    super.key,
  });

  final File file;
  final int? sizeBytes;

  @override
  Widget build(BuildContext context) {
    final fileName = file.uri.pathSegments.isEmpty
        ? 'Selected recording'
        : file.uri.pathSegments.last;
    final extension = _extension(fileName).toUpperCase();
    final size = sizeBytes;
    final isTooLarge = size != null && size > kUploadHardCapBytes;
    final isLarge = size != null && size > kUploadWarningThresholdBytes;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.insert_drive_file_outlined,
                  color: AppColors.cyan,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (extension.isNotEmpty) extension,
                        if (size != null) _formatBytes(size),
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isTooLarge || isLarge) ...[
            const SizedBox(height: AppSpacing.md),
            _FileNotice(
              icon: isTooLarge
                  ? Icons.error_outline
                  : Icons.warning_amber_outlined,
              color: isTooLarge ? AppColors.destructive : AppColors.warning,
              message: isTooLarge
                  ? 'This file is over 1 GB. Upload validation will reject it.'
                  : 'Large file selected. Upload may take a while on mobile data.',
            ),
          ],
        ],
      ),
    );
  }
}

class _FileNotice extends StatelessWidget {
  const _FileNotice({
    required this.icon,
    required this.color,
    required this.message,
  });

  final IconData icon;
  final Color color;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

String _extension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == fileName.length - 1) {
    return '';
  }
  return fileName.substring(dotIndex + 1);
}

String _formatBytes(int bytes) {
  const mb = 1024 * 1024;
  const gb = 1024 * 1024 * 1024;
  if (bytes >= gb) {
    return '${(bytes / gb).toStringAsFixed(2)} GB';
  }
  if (bytes >= mb) {
    return '${(bytes / mb).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}
