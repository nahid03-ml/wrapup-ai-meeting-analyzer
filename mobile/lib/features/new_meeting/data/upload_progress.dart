enum UploadStage {
  idle,
  validating,
  creatingMeeting,
  uploadingFile,
  creatingSession,
  enqueuingProcessing,
  done,
  failed,
}

sealed class UploadProgress {
  const UploadProgress({
    required this.stage,
    this.message,
    this.meetingId,
    this.sessionId,
  });

  final UploadStage stage;
  final String? message;
  final String? meetingId;
  final String? sessionId;

  bool get isWorking {
    return switch (stage) {
      UploadStage.validating ||
      UploadStage.creatingMeeting ||
      UploadStage.uploadingFile ||
      UploadStage.creatingSession ||
      UploadStage.enqueuingProcessing => true,
      UploadStage.idle || UploadStage.done || UploadStage.failed => false,
    };
  }
}

final class UploadIdle extends UploadProgress {
  const UploadIdle() : super(stage: UploadStage.idle);
}

final class UploadStageProgress extends UploadProgress {
  const UploadStageProgress(
    UploadStage stage, {
    super.message,
    super.meetingId,
    super.sessionId,
  }) : assert(
         stage != UploadStage.idle &&
             stage != UploadStage.done &&
             stage != UploadStage.failed,
         'Use UploadIdle, UploadDone, or UploadFailed for terminal states.',
       ),
       super(stage: stage);
}

final class UploadDone extends UploadProgress {
  const UploadDone({required String meetingId, required String sessionId})
    : super(
        stage: UploadStage.done,
        message: 'Upload complete.',
        meetingId: meetingId,
        sessionId: sessionId,
      );
}

final class UploadFailed extends UploadProgress {
  const UploadFailed({
    required this.error,
    required String message,
    super.meetingId,
    super.sessionId,
  }) : super(stage: UploadStage.failed, message: message);

  final Object error;
}

class UploadValidationException implements Exception {
  const UploadValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}
