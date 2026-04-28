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

  Future<void> runSmokeTest() async {
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
        statusText: 'Requesting microphone permission.',
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
          statusText: 'Microphone permission is required for live capture.',
          errorMessage:
              'Microphone permission was denied. Android capture cannot start.',
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

      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.serviceStarting,
        serviceStatus: 'starting',
        statusText: 'Starting Android live capture foreground service.',
      );

      await _capturePlatform.startCapture(const LiveCaptureConfig());
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
      state = state.copyWith(
        statusText: 'Stopping Android live capture foreground service.',
        serviceStatus: 'stopping',
        clearError: true,
      );
      await _capturePlatform.stopCapture();
      state = state.copyWith(
        status: AndroidCaptureSmokeTestStatus.serviceStopped,
        isServiceRunning: false,
        serviceStatus: 'stopped',
        statusText: 'Android live capture foreground service stopped.',
      );
    } on PlatformException catch (error) {
      _failWithMessage(
        error.message ?? 'Android capture service could not stop.',
        code: error.code,
      );
    } catch (error) {
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
        state = state.copyWith(
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
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.serviceStopped,
          isServiceRunning: false,
          serviceStatus: 'stopped',
          statusText: 'Android live capture foreground service stopped.',
          events: events,
        );
      case LiveCaptureEventType.audioLevel || LiveCaptureEventType.unknown:
        state = state.copyWith(events: events);
    }
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
      case 'serviceStopped':
        state = state.copyWith(
          status: AndroidCaptureSmokeTestStatus.serviceStopped,
          isServiceRunning: false,
          serviceStatus: 'stopped',
          statusText: 'Android live capture foreground service stopped.',
          events: events,
        );
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
    await _statusSubscription?.cancel();
    _statusSubscription = null;
    try {
      await _platform?.dispose();
    } catch (_) {
      // Best-effort smoke-test cleanup only.
    }
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
