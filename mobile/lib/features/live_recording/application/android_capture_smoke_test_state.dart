import '../data/android_live_capture_platform.dart';
import '../data/live_capture_event.dart';

enum AndroidCaptureSmokeTestStatus {
  idle,
  nonAndroid,
  unsupportedBelowAndroid10,
  android10To12Ready,
  android13NeedsNotificationPermission,
  android14PlusRequiresForegroundServiceTypes,
  requestingPermissions,
  requestingProjection,
  projectionGranted,
  projectionDenied,
  serviceStarting,
  serviceRunning,
  serviceStopped,
  serviceFailed,
  playbackCaptureStarting,
  playbackCaptureRunning,
  playbackCaptureStopped,
}

class AndroidCaptureSmokeTestState {
  const AndroidCaptureSmokeTestState({
    required this.status,
    required this.statusText,
    this.isAndroid = false,
    this.sdkInt,
    this.isSupported = false,
    this.isChecking = false,
    this.isRequestingPermissions = false,
    this.isRequestingProjection = false,
    this.isServiceRunning = false,
    this.microphonePermissionStatus = 'not checked',
    this.notificationPermissionStatus = 'not required',
    this.projectionStatus = 'not requested',
    this.serviceStatus = 'stopped',
    this.systemPlaybackStatus = 'not started',
    this.playbackReadStatus = 'not started',
    this.hasPlaybackFirstFrameRead = false,
    this.latestReadResult,
    this.audioRecordDetails,
    this.systemAudioLevel = 0.0,
    this.isSystemAudioSilent = true,
    this.systemAudioSampleRateHz,
    this.warnings = const <String>[],
    this.errorMessage,
    this.events = const <LiveCaptureEvent>[],
  });

  final AndroidCaptureSmokeTestStatus status;
  final String statusText;
  final bool isAndroid;
  final int? sdkInt;
  final bool isSupported;
  final bool isChecking;
  final bool isRequestingPermissions;
  final bool isRequestingProjection;
  final bool isServiceRunning;
  final String microphonePermissionStatus;
  final String notificationPermissionStatus;
  final String projectionStatus;
  final String serviceStatus;
  final String systemPlaybackStatus;
  final String playbackReadStatus;
  final bool hasPlaybackFirstFrameRead;
  final int? latestReadResult;
  final String? audioRecordDetails;
  final double systemAudioLevel;
  final bool isSystemAudioSilent;
  final int? systemAudioSampleRateHz;
  final List<String> warnings;
  final String? errorMessage;
  final List<LiveCaptureEvent> events;

  bool get canRun {
    return isAndroid &&
        isSupported &&
        !isChecking &&
        !isRequestingPermissions &&
        !isRequestingProjection &&
        !isServiceRunning;
  }

  bool get canStop =>
      isServiceRunning ||
      status == AndroidCaptureSmokeTestStatus.serviceStarting ||
      status == AndroidCaptureSmokeTestStatus.playbackCaptureStarting ||
      status == AndroidCaptureSmokeTestStatus.playbackCaptureRunning;

  String get versionBucketLabel {
    final sdk = sdkInt == null ? 'unknown SDK' : 'SDK $sdkInt';
    return switch (status) {
      AndroidCaptureSmokeTestStatus.nonAndroid => 'Non-Android platform',
      AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10 =>
        'Android below 10 ($sdk)',
      AndroidCaptureSmokeTestStatus.android10To12Ready => 'Android 10-12 ($sdk)',
      AndroidCaptureSmokeTestStatus.android13NeedsNotificationPermission =>
        'Android 13 ($sdk)',
      AndroidCaptureSmokeTestStatus.android14PlusRequiresForegroundServiceTypes =>
        'Android 14+ ($sdk)',
      _ => isAndroid ? 'Android ($sdk)' : 'Platform not checked',
    };
  }

  String get versionHelperText {
    return switch (status) {
      AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10 =>
        'Device audio capture requires Android 10 or newer.',
      AndroidCaptureSmokeTestStatus.android10To12Ready =>
        'Android will ask for screen/audio capture permission before starting the live capture service.',
      AndroidCaptureSmokeTestStatus.android13NeedsNotificationPermission =>
        'Android 13 also requires notification permission so WrapUp can show the live capture foreground notification.',
      AndroidCaptureSmokeTestStatus.android14PlusRequiresForegroundServiceTypes =>
        'Android 14+ requires microphone and media-projection foreground service permissions. If permission or service type is rejected, WrapUp will show the exact error.',
      AndroidCaptureSmokeTestStatus.nonAndroid =>
        'Android device audio capture can only be tested on Android.',
      _ => 'Check Android capture support before starting the smoke test.',
    };
  }

  AndroidCaptureSmokeTestState copyWith({
    AndroidCaptureSmokeTestStatus? status,
    String? statusText,
    bool? isAndroid,
    int? sdkInt,
    bool clearSdkInt = false,
    bool? isSupported,
    bool? isChecking,
    bool? isRequestingPermissions,
    bool? isRequestingProjection,
    bool? isServiceRunning,
    String? microphonePermissionStatus,
    String? notificationPermissionStatus,
    String? projectionStatus,
    String? serviceStatus,
    String? systemPlaybackStatus,
    String? playbackReadStatus,
    bool? hasPlaybackFirstFrameRead,
    int? latestReadResult,
    bool clearLatestReadResult = false,
    String? audioRecordDetails,
    bool clearAudioRecordDetails = false,
    double? systemAudioLevel,
    bool? isSystemAudioSilent,
    int? systemAudioSampleRateHz,
    bool clearSystemAudioSampleRateHz = false,
    List<String>? warnings,
    String? errorMessage,
    bool clearError = false,
    List<LiveCaptureEvent>? events,
  }) {
    return AndroidCaptureSmokeTestState(
      status: status ?? this.status,
      statusText: statusText ?? this.statusText,
      isAndroid: isAndroid ?? this.isAndroid,
      sdkInt: clearSdkInt ? null : sdkInt ?? this.sdkInt,
      isSupported: isSupported ?? this.isSupported,
      isChecking: isChecking ?? this.isChecking,
      isRequestingPermissions:
          isRequestingPermissions ?? this.isRequestingPermissions,
      isRequestingProjection:
          isRequestingProjection ?? this.isRequestingProjection,
      isServiceRunning: isServiceRunning ?? this.isServiceRunning,
      microphonePermissionStatus:
          microphonePermissionStatus ?? this.microphonePermissionStatus,
      notificationPermissionStatus:
          notificationPermissionStatus ?? this.notificationPermissionStatus,
      projectionStatus: projectionStatus ?? this.projectionStatus,
      serviceStatus: serviceStatus ?? this.serviceStatus,
      systemPlaybackStatus:
          systemPlaybackStatus ?? this.systemPlaybackStatus,
      playbackReadStatus: playbackReadStatus ?? this.playbackReadStatus,
      hasPlaybackFirstFrameRead:
          hasPlaybackFirstFrameRead ?? this.hasPlaybackFirstFrameRead,
      latestReadResult: clearLatestReadResult
          ? null
          : latestReadResult ?? this.latestReadResult,
      audioRecordDetails: clearAudioRecordDetails
          ? null
          : audioRecordDetails ?? this.audioRecordDetails,
      systemAudioLevel: systemAudioLevel ?? this.systemAudioLevel,
      isSystemAudioSilent: isSystemAudioSilent ?? this.isSystemAudioSilent,
      systemAudioSampleRateHz: clearSystemAudioSampleRateHz
          ? null
          : systemAudioSampleRateHz ?? this.systemAudioSampleRateHz,
      warnings: warnings ?? this.warnings,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      events: events ?? this.events,
    );
  }

  static const initial = AndroidCaptureSmokeTestState(
    status: AndroidCaptureSmokeTestStatus.idle,
    statusText: 'Android capture support has not been checked.',
  );

  static AndroidCaptureSmokeTestState fromEnvironment(
    AndroidCaptureEnvironment environment,
  ) {
    if (!environment.isAndroid) {
      return const AndroidCaptureSmokeTestState(
        status: AndroidCaptureSmokeTestStatus.nonAndroid,
        statusText: 'Android device audio capture can only be tested on Android.',
      );
    }

    final sdkInt = environment.sdkInt;
    if (!environment.isSupported || sdkInt == null || sdkInt < 29) {
      return AndroidCaptureSmokeTestState(
        status: AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10,
        statusText: 'Device audio capture requires Android 10 or newer.',
        isAndroid: true,
        sdkInt: sdkInt,
        isSupported: false,
      );
    }

    if (sdkInt >= 34) {
      return AndroidCaptureSmokeTestState(
        status:
            AndroidCaptureSmokeTestStatus.android14PlusRequiresForegroundServiceTypes,
        statusText: 'Ready to test Android 14+ foreground service startup.',
        isAndroid: true,
        sdkInt: sdkInt,
        isSupported: true,
      );
    }

    if (sdkInt >= 33) {
      return AndroidCaptureSmokeTestState(
        status: AndroidCaptureSmokeTestStatus.android13NeedsNotificationPermission,
        statusText: 'Ready to test Android 13 notification and projection flow.',
        isAndroid: true,
        sdkInt: sdkInt,
        isSupported: true,
      );
    }

    return AndroidCaptureSmokeTestState(
      status: AndroidCaptureSmokeTestStatus.android10To12Ready,
      statusText: 'Ready to test Android 10-12 projection flow.',
      isAndroid: true,
      sdkInt: sdkInt,
      isSupported: true,
    );
  }
}
