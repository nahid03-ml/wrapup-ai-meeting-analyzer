import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/languages/supported_languages.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/new_meeting_controller.dart';
import '../application/upload_limits_provider.dart';
import '../data/upload_progress.dart';
import 'widgets/file_picker_button.dart';
import 'widgets/instant_meeting_disabled_card.dart';
import 'widgets/language_picker_field.dart';
import 'widgets/new_meeting_choice_card.dart';
import 'widgets/plan_limit_banner.dart';
import 'widgets/selected_file_summary.dart';
import 'widgets/upload_progress_indicator.dart';

class NewMeetingPage extends ConsumerStatefulWidget {
  const NewMeetingPage({super.key});

  @override
  ConsumerState<NewMeetingPage> createState() => _NewMeetingPageState();
}

class _NewMeetingPageState extends ConsumerState<NewMeetingPage> {
  final _titleController = TextEditingController();

  File? _selectedFile;
  int? _selectedFileSize;
  late String _languageCode;
  String? _navigatedMeetingId;
  bool _isPickingFile = false;

  @override
  void initState() {
    super.initState();
    _languageCode = defaultSupportedLanguageCode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<UploadProgress>(newMeetingControllerProvider, (previous, next) {
      if (previous?.stage == next.stage &&
          previous?.meetingId == next.meetingId &&
          previous?.sessionId == next.sessionId) {
        return;
      }
      if (next is UploadDone) {
        if (_navigatedMeetingId != next.meetingId) {
          _navigatedMeetingId = next.meetingId;
          context.go('${AppRoutes.dashboardMeetings}/${next.meetingId}');
        }
      }
      if (next is UploadFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message ?? 'Upload failed.')),
        );
      }
    });

    final uploadProgress = ref.watch(newMeetingControllerProvider);
    final limitsValue = ref.watch(uploadLimitsProvider);
    final limitReached = limitsValue.maybeWhen(
      data: (limits) => limits.isAtDailyLimit,
      orElse: () => false,
    );
    final isWorking = uploadProgress.isWorking;
    final selectedFile = _selectedFile;
    final canPickFile = !isWorking && !limitReached && !_isPickingFile;
    final canUpload =
        selectedFile != null &&
        _languageCode.trim().isNotEmpty &&
        !limitReached &&
        !isWorking;

    return Scaffold(
      appBar: AppBar(title: const Text('New meeting')),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Start with a recording',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Upload audio or video now. Instant recording arrives next.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            PlanLimitBanner(
              value: limitsValue,
              onUpgrade: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Upgrade flow coming in Phase 9'),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            NewMeetingChoiceCard(
              icon: Icons.cloud_upload_outlined,
              title: 'Upload from device',
              subtitle: _isPickingFile
                  ? 'Opening your file picker...'
                  : 'Import an existing audio or video recording.',
              selected: true,
              enabled: canPickFile,
              onTap: canPickFile ? _pickFile : null,
              trailing: _isPickingFile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
            ),
            const SizedBox(height: AppSpacing.md),
            const InstantMeetingDisabledCard(),
            const SizedBox(height: AppSpacing.lg),
            _SupportedFormatsText(),
            const SizedBox(height: AppSpacing.lg),
            if (selectedFile != null)
              _UploadFormCard(
                file: selectedFile,
                fileSize: _selectedFileSize,
                titleController: _titleController,
                languageCode: _languageCode,
                enabled: !isWorking,
                canUpload: canUpload,
                onLanguageChanged: (code) {
                  setState(() {
                    _languageCode = code;
                  });
                },
                onPickDifferentFile: canPickFile ? _pickFile : null,
                onUpload: _startUpload,
              ),
            const SizedBox(height: AppSpacing.lg),
            UploadProgressIndicator(
              progress: uploadProgress,
              onRetry: selectedFile == null || isWorking ? null : _startUpload,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileSelected(File file) async {
    int? fileSize;
    try {
      fileSize = await file.length();
    } catch (_) {
      fileSize = null;
    }

    setState(() {
      _selectedFile = file;
      _selectedFileSize = fileSize;
      _titleController.text = _suggestMeetingTitle(file);
    });
  }

  Future<void> _pickFile() async {
    if (_isPickingFile) {
      return;
    }

    setState(() {
      _isPickingFile = true;
    });
    try {
      final file = await pickMeetingFile(context);
      if (file != null) {
        await _handleFileSelected(file);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingFile = false;
        });
      }
    }
  }

  Future<void> _startUpload() async {
    final file = _selectedFile;
    if (file == null) {
      return;
    }
    await ref
        .read(newMeetingControllerProvider.notifier)
        .startUpload(
          file: file,
          title: _titleController.text,
          language: _languageCode,
        );
  }
}

class _UploadFormCard extends StatefulWidget {
  const _UploadFormCard({
    required this.file,
    required this.fileSize,
    required this.titleController,
    required this.languageCode,
    required this.enabled,
    required this.canUpload,
    required this.onLanguageChanged,
    required this.onPickDifferentFile,
    required this.onUpload,
  });

  final File file;
  final int? fileSize;
  final TextEditingController titleController;
  final String languageCode;
  final bool enabled;
  final bool canUpload;
  final ValueChanged<String> onLanguageChanged;
  final VoidCallback? onPickDifferentFile;
  final VoidCallback onUpload;

  @override
  State<_UploadFormCard> createState() => _UploadFormCardState();
}

class _UploadFormCardState extends State<_UploadFormCard> {
  @override
  void initState() {
    super.initState();
    widget.titleController.addListener(_handleTitleChanged);
  }

  @override
  void didUpdateWidget(covariant _UploadFormCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.titleController != widget.titleController) {
      oldWidget.titleController.removeListener(_handleTitleChanged);
      widget.titleController.addListener(_handleTitleChanged);
    }
  }

  @override
  void dispose() {
    widget.titleController.removeListener(_handleTitleChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canUpload =
        widget.canUpload && widget.titleController.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectedFileSummary(file: widget.file, sizeBytes: widget.fileSize),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Meeting title',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: widget.titleController,
            enabled: widget.enabled,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(hintText: 'Untitled meeting'),
          ),
          const SizedBox(height: AppSpacing.lg),
          LanguagePickerField(
            value: widget.languageCode,
            enabled: widget.enabled,
            onChanged: widget.onLanguageChanged,
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canUpload ? widget.onUpload : null,
              icon: const Icon(Icons.auto_awesome_outlined),
              label: const Text('Upload & Process'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Center(
            child: TextButton(
              onPressed: widget.enabled ? widget.onPickDifferentFile : null,
              child: const Text('Pick a different file'),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTitleChanged() {
    setState(() {});
  }
}

class _SupportedFormatsText extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Text(
      'Supported formats: MP3, WAV, M4A, AAC, OGG, FLAC, MP4, MOV, WEBM, MKV. Up to 1 GB.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted, height: 1.35),
    );
  }
}

String _suggestMeetingTitle(File file) {
  final fileName = file.uri.pathSegments.isEmpty
      ? ''
      : file.uri.pathSegments.last;
  final dotIndex = fileName.lastIndexOf('.');
  final baseName = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
  final normalized = baseName.replaceAll(RegExp(r'[_-]+'), ' ').trim();
  if (normalized.isEmpty) {
    return 'Untitled meeting';
  }
  return normalized[0].toUpperCase() + normalized.substring(1);
}
