import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/backend_api.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../meetings/application/meetings_provider.dart';
import '../../meetings/data/meeting_detail_repository.dart';
import '../../meetings/data/meetings_repository.dart';
import '../data/upload_progress.dart';
import '../data/upload_repository.dart';
import 'upload_limits_provider.dart';

class NewMeetingController extends Notifier<UploadProgress> {
  @override
  UploadProgress build() => const UploadIdle();

  Future<void> startUpload({
    required File file,
    required String title,
    required String language,
  }) async {
    String? createdMeetingId;
    String? uploadedStorageRef;
    String? createdSessionId;

    try {
      state = const UploadStageProgress(
        UploadStage.validating,
        message: 'Checking file and account limits.',
      );

      final authSession = ref.read(currentSessionProvider);
      final user = authSession?.user;
      if (authSession == null || user == null) {
        throw const UploadValidationException(
          'Authentication session missing. Please log in again.',
        );
      }

      final trimmedTitle = title.trim();
      final trimmedLanguage = language.trim();
      final fileSize = await _validateFileAndInputs(
        file: file,
        title: trimmedTitle,
        language: trimmedLanguage,
      );

      final limits = await ref.read(uploadLimitsProvider.future);
      _validateLimits(fileSize: fileSize, limits: limits);

      state = const UploadStageProgress(
        UploadStage.creatingMeeting,
        message: 'Creating meeting.',
      );
      final meetingsRepository = ref.read(meetingsRepositoryProvider);
      final meeting = await meetingsRepository.createMeeting(
        title: trimmedTitle,
        source: 'uploaded',
      );
      createdMeetingId = meeting.id;

      state = UploadStageProgress(
        UploadStage.uploadingFile,
        message: 'Uploading recording.',
        meetingId: createdMeetingId,
      );
      final uploadRepository = ref.read(uploadRepositoryProvider);
      uploadedStorageRef = await uploadRepository.uploadAudioFile(
        file: file,
        userId: user.id,
        meetingId: createdMeetingId,
      );

      state = UploadStageProgress(
        UploadStage.creatingSession,
        message: 'Creating processing session.',
        meetingId: createdMeetingId,
      );
      final detailRepository = ref.read(meetingDetailRepositoryProvider);
      final session = await detailRepository.insertSessionForUpload(
        meetingId: createdMeetingId,
        audioFileUrl: uploadedStorageRef,
        language: trimmedLanguage,
      );
      createdSessionId = session.id;

      state = UploadStageProgress(
        UploadStage.enqueuingProcessing,
        message: 'Starting AI processing.',
        meetingId: createdMeetingId,
        sessionId: createdSessionId,
      );
      final backendApi = ref.read(backendApiProvider);
      try {
        await backendApi.processSession(createdSessionId);
      } catch (error) {
        _invalidateUploadData();
        state = UploadFailed(
          error: error,
          message:
              'File uploaded, but processing could not start. Please retry later.',
          meetingId: createdMeetingId,
          sessionId: createdSessionId,
        );
        return;
      }

      _invalidateUploadData();
      state = UploadDone(
        meetingId: createdMeetingId,
        sessionId: createdSessionId,
      );
    } catch (error) {
      await _rollbackFailedUpload(
        meetingId: createdMeetingId,
        storageRef: uploadedStorageRef,
        sessionId: createdSessionId,
      );
      if (createdMeetingId != null) {
        _invalidateUploadData();
      }
      state = UploadFailed(
        error: error,
        message: _uploadErrorMessage(error),
        meetingId: createdMeetingId,
        sessionId: createdSessionId,
      );
    }
  }

  Future<void> _rollbackFailedUpload({
    required String? meetingId,
    required String? storageRef,
    required String? sessionId,
  }) async {
    if (sessionId != null) {
      return;
    }

    if (storageRef != null) {
      try {
        await ref.read(uploadRepositoryProvider).deleteUploadedFile(storageRef);
      } catch (_) {
        // Best-effort rollback. Preserve the original upload failure.
      }
    }

    if (meetingId != null) {
      try {
        await ref
            .read(meetingsRepositoryProvider)
            .hardDeleteMeetingForRollback(meetingId);
      } catch (_) {
        // Best-effort rollback. Preserve the original upload failure.
      }
    }
  }

  void _invalidateUploadData() {
    ref.invalidate(meetingsListProvider);
    ref.invalidate(uploadLimitsProvider);
  }
}

Future<int> _validateFileAndInputs({
  required File file,
  required String title,
  required String language,
}) async {
  if (title.isEmpty) {
    throw const UploadValidationException('Meeting title is required.');
  }
  if (language.isEmpty) {
    throw const UploadValidationException('Audio language is required.');
  }
  if (!await file.exists()) {
    throw const UploadValidationException('Selected file does not exist.');
  }

  final extension = _extensionFor(file);
  if (!kAllowedUploadExtensions.contains(extension)) {
    throw UploadValidationException(
      'Unsupported file type .$extension. Please choose an audio or video file.',
    );
  }

  final fileSize = await file.length();
  if (fileSize > kUploadHardCapBytes) {
    throw const UploadValidationException(
      'File is larger than the 1 GB mobile upload limit.',
    );
  }
  return fileSize;
}

void _validateLimits({required int fileSize, required UploadLimits limits}) {
  if (limits.isAtDailyLimit) {
    throw UploadValidationException(
      '${limits.label} daily upload limit reached. Please wait until tomorrow or upgrade.',
    );
  }

  final planMaxBytes = limits.maxFileSizeBytes;
  if (planMaxBytes != null && fileSize > planMaxBytes) {
    throw UploadValidationException(
      'File is too large for the ${limits.label} plan. Maximum upload size is ${limits.maxFileSizeMb} MB.',
    );
  }
}

String _extensionFor(File file) {
  final name = file.uri.pathSegments.isEmpty
      ? ''
      : file.uri.pathSegments.last.toLowerCase();
  final dotIndex = name.lastIndexOf('.');
  if (dotIndex == -1 || dotIndex == name.length - 1) {
    return '';
  }
  return name.substring(dotIndex + 1);
}

String _uploadErrorMessage(Object error) {
  if (error is UploadValidationException) {
    return error.message;
  }
  final message = error.toString().trim();
  if (message.isEmpty) {
    return 'Upload failed.';
  }
  return message;
}

final newMeetingControllerProvider =
    NotifierProvider.autoDispose<NewMeetingController, UploadProgress>(
      NewMeetingController.new,
    );
