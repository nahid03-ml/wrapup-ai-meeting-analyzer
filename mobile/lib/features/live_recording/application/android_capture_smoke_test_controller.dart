import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../data/android_live_capture_platform.dart';
import '../data/live_capture_config.dart';
import '../data/live_capture_event.dart';
import 'android_capture_smoke_test_state.dart';

class AndroidCaptureSmokeTestController
    extends Notifier<AndroidCaptureSmokeTestState> {
  AndroidLiveCapturePlatform? _platform;
  StreamSubscription<LiveCaptureEvent>? _statusSubscription;
  Timer? _stopConfirmationTimer;
  bool _waitingForStopConfirmation = false;

  AndroidLiveCapturePlatform get _capturePlatform {
    return _platform ??= AndroidLiveCapturePlatform();
  }

  @override
  AndroidCaptureSmokeTestState build() {
    ref.onDispose(() {
      unawaited(_dispose());
    });
    return AndroidCaptureSmokeTestState.initial;
  }

  Future<void> checkEnvironment() async {
    state = state.copyWith(
      isChecking: true,
      statusText: 'Checking Android capture support.',
      clearError: true,
    );

    try {
      final environment = await _capturePlatform.getAndroidCaptureEnvironment();
      state = AndroidCaptureSmokeTestState.fromEnvironment(environment);
    } catch (error) {
      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.serviceFailed,
        statusText: 'Could not check Android capture support.',
        isChecking: false,
        errorMessage: _messageForError(error),
      );
    }
  }

  Future<void> runSmokeTest() => runSystemPlaybackTest();

  Future<void> runSystemPlaybackTest() async {
    await _runCaptureProof(
      captureSystemAudio: true,
      captureMicrophone: false,
      requiresProjection: true,
    );
  }

  Future<void> runMicrophoneTest() async {
    await _runCaptureProof(
      captureSystemAudio: false,
      captureMicrophone: true,
      requiresProjection: false,
    );
  }

  Future<void> _runCaptureProof({
    required bool captureSystemAudio,
    required bool captureMicrophone,
    required bool requiresProjection,
  }) async {
    await _ensureStatusSubscription();

    final environment = await _capturePlatform.getAndroidCaptureEnvironment();
    final environmentState = AndroidCaptureSmokeTestState.fromEnvironment(
      environment,
    );
    state = environmentState.copyWith(clearError: true);

    if (!environmentState.isAndroid || !environmentState.isSupported) {
      return;
    }

    try {
      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.requestingPermissions,
        isRequestingPermissions: true,
        statusText: 'Requesting Android audio capture permission.',
        clearError: true,
      );

      final microphoneStatus = await Permission.microphone.request();
      state = state.copyWith(
        microphonePermissionStatus: _permissionLabel(microphoneStatus),
      );
      if (!microphoneStatus.isGranted) {
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.serviceFailed,
          isRequestingPermissions: false,
          statusText:
              'Android audio capture permission is required for this proof.',
          errorMessage:
              'Audio capture permission was denied. Android playback capture cannot start.',
        );
        return;
      }

      if (environment.requiresNotificationRuntimePermission) {
        state = state.copyWith(
          statusText: 'Requesting notification permission.',
        );
        final notificationStatus = await Permission.notification.request();
        state = state.copyWith(
          notificationPermissionStatus: _permissionLabel(notificationStatus),
        );
        if (!notificationStatus.isGranted) {
          state = state.copyWith(
            status: AndroidCaptureSmokeTestStatus.serviceFailed,
            isRequestingPermissions: false,
            statusText:
                'Notification permission is required for the foreground service notification.',
            errorMessage:
                'Notification permission was denied. WrapUp needs a foreground service notification for Android live capture.',
          );
          return;
        }
      } else {
        state = state.copyWith(notificationPermissionStatus: 'not required');
      }

      if (requiresProjection) {
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.requestingProjection,
          isRequestingPermissions: false,
          isRequestingProjection: true,
          projectionStatus: 'requesting',
          statusText: 'Requesting Android screen/audio capture permission.',
        );

        final projection = await _capturePlatform.requestProjection();
        if (!projection.granted) {
          state = state.copyWith(
            status: AndroidCaptureSmokeTestStatus.projectionDenied,
            isRequestingProjection: false,
            projectionStatus: 'denied',
            statusText: 'MediaProjection permission was denied.',
            errorMessage:
                projection.message ?? 'MediaProjection permission was denied.',
          );
          return;
        }

        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.projectionGranted,
          isRequestingProjection: false,
          projectionStatus: 'granted',
          statusText: 'MediaProjection granted. Starting foreground service.',
        );
      } else {
        state = state.copyWith(
          isRequestingPermissions: false,
          isRequestingProjection: false,
          projectionStatus: 'not required',
          statusText: 'Starting microphone foreground service.',
        );
      }

      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.serviceStarting,
        serviceStatus: 'starting',
        systemPlaybackStatus:
            captureSystemAudio ? 'not started' : state.systemPlaybackStatus,
        playbackReadStatus:
            captureSystemAudio ? 'not started' : state.playbackReadStatus,
        hasPlaybackFirstFrameRead:
            captureSystemAudio ? false : state.hasPlaybackFirstFrameRead,
        clearLatestReadResult: captureSystemAudio,
        clearAudioRecordDetails: captureSystemAudio,
        micCaptureStatus:
            captureMicrophone ? 'not started' : state.micCaptureStatus,
        micReadStatus: captureMicrophone ? 'not started' : state.micReadStatus,
        hasMicFirstFrameRead:
            captureMicrophone ? false : state.hasMicFirstFrameRead,
        clearLatestMicReadResult: captureMicrophone,
        clearMicAudioRecordDetails: captureMicrophone,
        micAudioLevel: captureMicrophone ? 0.0 : state.micAudioLevel,
        isMicSilent: captureMicrophone ? true : state.isMicSilent,
        clearMicAudioSampleRateHz: captureMicrophone,
        clearMicAudioSource: captureMicrophone,
        systemAudioLevel: captureSystemAudio ? 0.0 : state.systemAudioLevel,
        isSystemAudioSilent:
            captureSystemAudio ? true : state.isSystemAudioSilent,
        clearSystemAudioSampleRateHz: captureSystemAudio,
        statusText: 'Starting Android live capture foreground service.',
      );

      await _capturePlatform.startCapture(
        LiveCaptureConfig(
          captureSystemAudio: captureSystemAudio,
          captureMicrophone: captureMicrophone,
        ),
      );
      state = state.copyWith(
        statusText: 'Waiting for foreground service status.',
      );
    } on PlatformException catch (error) {
      _failWithMessage(
        error.message ?? 'Android capture smoke test failed.',
        code: error.code,
      );
    } catch (error) {
      _failWithMessage(_messageForError(error));
    } finally {
      if (state.isRequestingPermissions || state.isRequestingProjection) {
        state = state.copyWith(
          isRequestingPermissions: false,
          isRequestingProjection: false,
        );
      }
    }
  }

  Future<void> stopSmokeTest() async {
    try {
      _stopConfirmationTimer?.cancel();
      _waitingForStopConfirmation = true;
      state = state.copyWith(
        statusText: 'Stopping Android live capture foreground service.',
        serviceStatus: 'stopping',
        systemPlaybackStatus: 'stopping',
        playbackReadStatus: 'stop requested',
        micCaptureStatus: 'stopping',
        micReadStatus: 'stop requested',
        clearError: true,
      );
      await _capturePlatform.stopCapture();
      if (_waitingForStopConfirmation) {
        _startStopConfirmationTimeout();
      }
    } on PlatformException catch (error) {
      _waitingForStopConfirmation = false;
      _stopConfirmationTimer?.cancel();
      _failWithMessage(
        error.message ?? 'Android capture service could not stop.',
        code: error.code,
      );
    } catch (error) {
      _waitingForStopConfirmation = false;
      _stopConfirmationTimer?.cancel();
      _failWithMessage(_messageForError(error));
    }
  }

  void reset() {
    state = AndroidCaptureSmokeTestState.initial;
  }

  Future<void> _ensureStatusSubscription() async {
    if (_statusSubscription != null) {
      return;
    }
    _statusSubscription = _capturePlatform.statusEvents.listen(
      _handleStatusEvent,
      onError: (Object error) {
        _failWithMessage(_messageForError(error));
      },
    );
  }

  void _handleStatusEvent(LiveCaptureEvent event) {
    final events = List<LiveCaptureEvent>.unmodifiable(<LiveCaptureEvent>[
      event,
      ...state.events,
    ].take(8));

    switch (event.eventType) {
      case LiveCaptureEventType.status:
        _handleStatusValue(event, events);
      case LiveCaptureEventType.warning:
        final isNoFramesWarning = event.code == 'playbackCaptureNoFrames';
        final isMicNoFramesWarning = event.code == 'microphoneCaptureNoFrames';
        final isMicSilentWarning = event.code == 'microphoneSilent';
        state = state.copyWith(
          systemPlaybackStatus: event.code == 'systemPlaybackSilent'
              ? 'silent'
              : state.systemPlaybackStatus,
          isSystemAudioSilent: event.code == 'systemPlaybackSilent'
              ? true
              : state.isSystemAudioSilent,
          playbackReadStatus: isNoFramesWarning
              ? 'no frames read'
              : state.playbackReadStatus,
          micCaptureStatus:
              isMicSilentWarning ? 'silent' : state.micCaptureStatus,
          isMicSilent: isMicSilentWarning ? true : state.isMicSilent,
          micReadStatus: isMicNoFramesWarning
              ? 'no frames read'
              : state.micReadStatus,
          warnings: List<String>.unmodifiable(<String>[
            event.message ?? 'Android capture warning.',
            ...state.warnings,
          ].take(4)),
          events: events,
        );
      case LiveCaptureEventType.error:
        _failWithMessage(
          event.message ?? 'Android capture service failed.',
          code: event.code,
          events: events,
        );
      case LiveCaptureEventType.stopped:
        _markNativeStopped(events);
      case LiveCaptureEventType.audioLevel:
        _handleAudioLevelEvent(event, events);
      case LiveCaptureEventType.unknown:
        state = state.copyWith(events: events);
    }
  }

  void _handleAudioLevelEvent(
    LiveCaptureEvent event,
    List<LiveCaptureEvent> events,
  ) {
    if (event.source == 'microphone') {
      final level = (event.level ?? 0.0).clamp(0.0, 1.0).toDouble();
      final isSilent = event.isSilent ?? level < 0.01;
      state = state.copyWith(
        status: state.isServiceRunning
            ? AndroidCaptureSmokeTestStatus.playbackCaptureRunning
            : state.status,
        micAudioLevel: level,
        isMicSilent: isSilent,
        hasMicFirstFrameRead: true,
        micAudioSampleRateHz: event.sampleRateHz,
        micAudioSource: event.audioSource,
        micCaptureStatus: isSilent ? 'silent' : 'audio detected',
        micReadStatus: isSilent ? 'reading silent frames' : 'reading audio',
        events: events,
      );
      return;
    }

    if (event.source != 'systemPlayback') {
      state = state.copyWith(events: events);
      return;
    }

    final level = (event.level ?? 0.0).clamp(0.0, 1.0).toDouble();
    final isSilent = event.isSilent ?? level < 0.01;
    state = state.copyWith(
      status: state.isServiceRunning
          ? AndroidCaptureSmokeTestStatus.playbackCaptureRunning
          : state.status,
      systemAudioLevel: level,
      isSystemAudioSilent: isSilent,
      hasPlaybackFirstFrameRead: true,
      systemAudioSampleRateHz: event.sampleRateHz,
      systemPlaybackStatus: isSilent ? 'silent' : 'audio detected',
      playbackReadStatus: isSilent ? 'reading silent frames' : 'reading audio',
      events: events,
    );
  }

  void _handleStatusValue(
    LiveCaptureEvent event,
    List<LiveCaptureEvent> events,
  ) {
    switch (event.status) {
      case 'unsupportedAndroidVersion':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10,
          isSupported: false,
          statusText:
              event.message ?? 'Device audio capture requires Android 10 or newer.',
          events: events,
        );
      case 'requestingProjection':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.requestingProjection,
          isRequestingProjection: true,
          projectionStatus: 'requesting',
          statusText: 'Requesting Android screen/audio capture permission.',
          events: events,
        );
      case 'projectionRequired':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.projectionDenied,
          projectionStatus: 'required',
          statusText:
              event.message ?? 'MediaProjection permission is required.',
          events: events,
        );
      case 'projectionGranted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.projectionGranted,
          isRequestingProjection: false,
          projectionStatus: 'granted',
          statusText: 'MediaProjection permission granted.',
          events: events,
        );
      case 'projectionDenied':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.projectionDenied,
          isRequestingProjection: false,
          projectionStatus: 'denied',
          statusText: event.message ?? 'MediaProjection permission denied.',
          errorMessage: event.message ?? 'MediaProjection permission denied.',
          events: events,
        );
      case 'startingService':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.serviceStarting,
          serviceStatus: 'starting',
          statusText: 'Starting Android live capture foreground service.',
          events: events,
        );
      case 'stoppingService' || 'serviceStopRequested':
        state = state.copyWith(
          serviceStatus: 'stopping',
          systemPlaybackStatus: 'stopping',
          playbackReadStatus: 'stop requested',
          micCaptureStatus: 'stopping',
          micReadStatus: 'stop requested',
          statusText:
              event.message ?? 'Stopping Android live capture foreground service.',
          events: events,
        );
      case 'serviceStarted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.serviceRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          statusText:
              event.message ?? 'Android live capture foreground service started.',
          events: events,
          clearError: true,
        );
      case 'audioRecordBuilt':
        state = state.copyWith(
          systemPlaybackStatus: 'AudioRecord built',
          playbackReadStatus: 'built',
          systemAudioSampleRateHz: event.sampleRateHz,
          audioRecordDetails: _audioRecordDetails(event),
          statusText: event.message ?? 'Playback AudioRecord was built.',
          events: events,
          clearError: true,
        );
      case 'audioRecordStartRequested':
        state = state.copyWith(
          systemPlaybackStatus: 'starting AudioRecord',
          playbackReadStatus: 'start requested',
          latestReadResult: event.readResult,
          statusText: event.message ?? 'Starting playback AudioRecord.',
          events: events,
          clearError: true,
        );
      case 'audioRecordRecording':
        state = state.copyWith(
          systemPlaybackStatus: 'recording',
          playbackReadStatus: 'recording',
          statusText:
              event.message ?? 'Playback AudioRecord entered recording state.',
          events: events,
          clearError: true,
        );
      case 'playbackCaptureStarting':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureStarting,
          isServiceRunning: true,
          serviceStatus: 'running',
          systemPlaybackStatus: 'starting',
          statusText:
              event.message ?? 'Starting Android system playback AudioRecord.',
          events: events,
          clearError: true,
        );
      case 'playbackCaptureStopRequested':
        state = state.copyWith(
          systemPlaybackStatus: 'stopping',
          playbackReadStatus: 'stop requested',
          statusText:
              event.message ?? 'Stopping Android system playback capture.',
          events: events,
        );
      case 'playbackCaptureStarted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          systemPlaybackStatus: 'running',
          systemAudioSampleRateHz: event.sampleRateHz,
          statusText:
              'This Phase 6F proof captures Android system playback only. Microphone capture is not active yet.',
          events: events,
          clearError: true,
        );
      case 'playbackReadStarted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          playbackReadStatus: 'waiting for frames',
          statusText:
              event.message ?? 'Playback capture read loop started.',
          events: events,
          clearError: true,
        );
      case 'playbackReadNoData':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          playbackReadStatus: 'no data yet',
          latestReadResult: event.readResult,
          statusText:
              event.message ?? 'Playback capture read returned no data yet.',
          events: events,
          clearError: true,
        );
      case 'playbackFirstFrameRead':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          systemPlaybackStatus: 'frames detected',
          playbackReadStatus: 'first frame read',
          hasPlaybackFirstFrameRead: true,
          latestReadResult: event.readResult,
          systemAudioSampleRateHz: event.sampleRateHz,
          statusText: event.message ?? 'First playback audio frame was read.',
          events: events,
          clearError: true,
        );
      case 'deviceAudioDetected':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          systemPlaybackStatus: 'audio detected',
          isSystemAudioSilent: false,
          statusText: event.message ?? 'Device audio detected.',
          events: events,
          clearError: true,
        );
      case 'microphoneAudioRecordBuilt':
        state = state.copyWith(
          micCaptureStatus: 'AudioRecord built',
          micReadStatus: 'built',
          micAudioSampleRateHz: event.sampleRateHz,
          micAudioSource: event.audioSource,
          micAudioRecordDetails: _audioRecordDetails(event),
          statusText: event.message ?? 'Microphone AudioRecord was built.',
          events: events,
          clearError: true,
        );
      case 'microphoneAudioRecordStartRequested':
        state = state.copyWith(
          micCaptureStatus: 'starting AudioRecord',
          micReadStatus: 'start requested',
          latestMicReadResult: event.readResult,
          micAudioSource: event.audioSource,
          statusText: event.message ?? 'Starting microphone AudioRecord.',
          events: events,
          clearError: true,
        );
      case 'microphoneAudioRecordRecording':
        state = state.copyWith(
          micCaptureStatus: 'recording',
          micReadStatus: 'recording',
          micAudioSource: event.audioSource,
          statusText:
              event.message ?? 'Microphone AudioRecord entered recording state.',
          events: events,
          clearError: true,
        );
      case 'microphoneCaptureStarting':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureStarting,
          isServiceRunning: true,
          serviceStatus: 'running',
          micCaptureStatus: 'starting',
          statusText:
              event.message ?? 'Starting Android microphone AudioRecord.',
          events: events,
          clearError: true,
        );
      case 'microphoneCaptureStarted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          micCaptureStatus: 'running',
          micAudioSampleRateHz: event.sampleRateHz,
          micAudioSource: event.audioSource,
          statusText:
              'This checks microphone capture only. It does not mix mic with system audio yet.',
          events: events,
          clearError: true,
        );
      case 'microphoneReadStarted':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          micReadStatus: 'waiting for frames',
          micAudioSource: event.audioSource,
          statusText: event.message ?? 'Microphone capture read loop started.',
          events: events,
          clearError: true,
        );
      case 'microphoneReadNoData':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          micReadStatus: 'no data yet',
          latestMicReadResult: event.readResult,
          micAudioSource: event.audioSource,
          statusText:
              event.message ?? 'Microphone capture read returned no data yet.',
          events: events,
          clearError: true,
        );
      case 'microphoneFirstFrameRead':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          micCaptureStatus: 'frames detected',
          micReadStatus: 'first frame read',
          hasMicFirstFrameRead: true,
          latestMicReadResult: event.readResult,
          micAudioSampleRateHz: event.sampleRateHz,
          micAudioSource: event.audioSource,
          statusText: event.message ?? 'First microphone audio frame was read.',
          events: events,
          clearError: true,
        );
      case 'microphoneAudioDetected':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureRunning,
          isServiceRunning: true,
          serviceStatus: 'running',
          micCaptureStatus: 'audio detected',
          isMicSilent: false,
          micAudioSource: event.audioSource,
          statusText: event.message ?? 'Microphone audio detected.',
          events: events,
          clearError: true,
        );
      case 'microphoneReadStopped':
        state = state.copyWith(
          micReadStatus: 'stopped',
          statusText: event.message ?? 'Microphone capture read loop stopped.',
          events: events,
        );
      case 'microphoneCaptureStopRequested':
        state = state.copyWith(
          micCaptureStatus: 'stopping',
          micReadStatus: 'stop requested',
          statusText: event.message ?? 'Stopping Android microphone capture.',
          events: events,
        );
      case 'microphoneCaptureStopped':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureStopped,
          micCaptureStatus: 'stopped',
          micReadStatus: 'stopped',
          statusText: event.message ?? 'Microphone capture stopped.',
          events: events,
        );
      case 'playbackReadStopped':
        state = state.copyWith(
          playbackReadStatus: 'stopped',
          statusText: event.message ?? 'Playback capture read loop stopped.',
          events: events,
        );
      case 'playbackCaptureStopped':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.playbackCaptureStopped,
          systemPlaybackStatus: 'stopped',
          playbackReadStatus: 'stopped',
          statusText: event.message ?? 'System playback capture stopped.',
          events: events,
        );
      case 'serviceStopped':
        _markNativeStopped(events);
      case 'idle':
        state = state.copyWith(events: events);
      default:
        state = state.copyWith(
          statusText: event.message ?? 'Android capture status updated.',
          events: events,
        );
    }
  }

  void _failWithMessage(
    String message, {
    String? code,
    List<LiveCaptureEvent>? events,
  }) {
    final fullMessage = code == null ? message : '$code: $message';
    state = state.copyWith(
      status: AndroidCaptureSmokeTestStatus.serviceFailed,
      isRequestingPermissions: false,
      isRequestingProjection: false,
      isServiceRunning: false,
      serviceStatus: 'failed',
      statusText: 'Android capture smoke test failed.',
      errorMessage: fullMessage,
      events: events,
    );
  }

  Future<void> _dispose() async {
    _stopConfirmationTimer?.cancel();
    _stopConfirmationTimer = null;
    _waitingForStopConfirmation = false;
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    try {
      await _platform?.dispose();
    } catch (_) {
      // Best-effort smoke-test cleanup only.
    }
  }

  void _startStopConfirmationTimeout() {
    _stopConfirmationTimer?.cancel();
    _stopConfirmationTimer = Timer(const Duration(seconds: 3), () {
      if (!_waitingForStopConfirmation) {
        return;
      }
      _waitingForStopConfirmation = false;
      const warning =
          'Stop command sent. Native service did not confirm stop within 3 seconds.';
      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.serviceStopped,
        isServiceRunning: false,
        serviceStatus: 'stopped',
        systemPlaybackStatus: 'stopped',
        playbackReadStatus: 'stopped',
        micCaptureStatus: 'stopped',
        micReadStatus: 'stopped',
        statusText: warning,
        warnings: List<String>.unmodifiable(<String>[
          warning,
          ...state.warnings,
        ].take(4)),
      );
    });
  }

  void _markNativeStopped(List<LiveCaptureEvent> events) {
    _waitingForStopConfirmation = false;
    _stopConfirmationTimer?.cancel();
    _stopConfirmationTimer = null;
    state = state.copyWith(
      status: AndroidCaptureSmokeTestStatus.serviceStopped,
      isServiceRunning: false,
      serviceStatus: 'stopped',
      systemPlaybackStatus: 'stopped',
      playbackReadStatus: 'stopped',
      micCaptureStatus: 'stopped',
      micReadStatus: 'stopped',
      statusText: 'Android live capture foreground service stopped.',
      events: events,
    );
  }
}

String _permissionLabel(PermissionStatus status) {
  if (status.isGranted) return 'granted';
  if (status.isDenied) return 'denied';
  if (status.isPermanentlyDenied) return 'permanently denied';
  if (status.isRestricted) return 'restricted';
  if (status.isLimited) return 'limited';
  return status.toString();
}

String _messageForError(Object error) {
  final message = error.toString().trim();
  return message.isEmpty ? 'Android capture smoke test failed.' : message;
}

String? _audioRecordDetails(LiveCaptureEvent event) {
  final parts = <String>[];
  final sampleRateHz = event.sampleRateHz;
  if (sampleRateHz != null) {
    parts.add('$sampleRateHz Hz');
  }
  final channelCount = event.channelCount;
  if (channelCount != null) {
    parts.add(channelCount == 1 ? 'mono' : '$channelCount channels');
  }
  final bufferSizeBytes = event.bufferSizeBytes;
  if (bufferSizeBytes != null) {
    parts.add('$bufferSizeBytes B buffer');
  }
  final audioSource = event.audioSource;
  if (audioSource != null) {
    parts.add(audioSource);
  }
  return parts.isEmpty ? null : parts.join(' - ');
}
