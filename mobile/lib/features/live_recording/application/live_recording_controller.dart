import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/config/env.dart';
import '../../../core/languages/supported_languages.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../meetings/application/meeting_detail_provider.dart';
import '../../meetings/application/meetings_provider.dart';
import '../data/android_live_capture_platform.dart';
import '../data/live_capture_event.dart';
import '../data/live_capture_config.dart';
import '../data/live_event.dart';
import '../data/live_session_repository.dart';
import '../data/live_websocket_client.dart';
import '../data/live_websocket_url_builder.dart';
import 'live_limits_provider.dart';
import 'live_recording_state.dart';
import 'live_transcript_line.dart';

const kLiveStopDoneTimeout = Duration(seconds: 30);
const _backgroundWarning = 'Live capture continued in the background.';
const _longPauseNoticeDuration = Duration(minutes: 2);
const _longPauseWarningDuration = Duration(minutes: 5);
const _longPauseNotice = 'Capture is paused. Resume when you are ready.';
const _longPauseWarning =
    'Long pauses may affect the live connection. Resume or stop when ready.';
const _pausedHeartbeatInterval = Duration(seconds: 4);

class LiveRecordingController extends Notifier<LiveRecordingState>
    with WidgetsBindingObserver {
  LiveWebSocketClient? _client;
  AndroidLiveCapturePlatform? _capturePlatform;
  StreamSubscription<LiveBackendEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription? _captureStatusSubscription;
  Completer<LiveDoneEvent>? _doneCompleter;
  Completer<void>? _stopCompleter;
  Completer<void>? _resumeCompleter;
  Timer? _pausedHeartbeatTimer;

  String? _meetingId;
  String? _sessionId;
  String? _languageCode;
  List<LiveTranscriptLine> _transcriptLines = const <LiveTranscriptLine>[];
  List<String> _messages = const <String>[];
  List<String> _warnings = const <String>[];
  String _webSocketStatus = 'idle';
  String _captureStatus = 'idle';
  int _pcmChunksSent = 0;
  int _pcmChunksDropped = 0;
  int _pcmChunksSkippedWhilePaused = 0;
  int _lastPcmChunkBytes = 0;
  double _audioLevel = 0;
  bool _hasAudioLevel = false;
  bool _isAudioDetected = false;
  String? _audioLevelSource;
  DateTime? _lastPcmMetricsPublishedAt;
  bool _stopMessageSent = false;
  bool _captureStopRequested = false;
  bool _failureCleanupStarted = false;
  bool _isPaused = false;
  bool _lifecycleObserverAttached = false;
  bool _wasStreamingInBackground = false;
  Timer? _durationTimer;
  DateTime? _captureStartedAt;
  DateTime? _captureStoppedAt;
  DateTime? _pauseStartedAt;
  DateTime? _lastTranscriptEventAt;
  DateTime? _lastPcmSentAt;
  DateTime? _lastBackendEventAt;
  DateTime? _lastBackgroundedAt;
  Duration _pausedDuration = Duration.zero;
  int _appBackgroundCount = 0;
  int _appForegroundReturnCount = 0;
  bool _longPauseNoticeAdded = false;
  bool _longPauseWarningAdded = false;
  int _resumeCount = 0;
  DateTime? _lastResumeAt;
  int _pcmChunksSentAfterResume = 0;
  DateTime? _lastPcmSentAfterResumeAt;
  DateTime? _lastTranscriptAfterResumeAt;
  bool _isSendingAudioAfterResume = false;
  int _pausedHeartbeatCount = 0;
  DateTime? _lastPausedHeartbeatAt;

  AndroidLiveCapturePlatform get _androidCapturePlatform {
    return _capturePlatform ??= AndroidLiveCapturePlatform();
  }

  void _logLive(
    String tag,
    String message, [
    Map<String, Object?> data = const {},
  ]) {
    final fields = data.entries
        .where((entry) => entry.value != null)
        .map((entry) => '${entry.key}=${entry.value}')
        .join(' ');
    developer.log(fields.isEmpty ? message : '$message $fields', name: tag);
  }

  @override
  LiveRecordingState build() {
    if (!_lifecycleObserverAttached) {
      WidgetsBinding.instance.addObserver(this);
      _lifecycleObserverAttached = true;
    }
    ref.onDispose(() {
      if (_lifecycleObserverAttached) {
        WidgetsBinding.instance.removeObserver(this);
        _lifecycleObserverAttached = false;
      }
      unawaited(_dispose());
    });
    return const LiveIdle();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_wasStreamingInBackground) {
        _wasStreamingInBackground = false;
        _appForegroundReturnCount += 1;
        _addWarning(_backgroundWarning);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (this.state is LiveStreaming || this.state is LivePaused) {
        if (!_wasStreamingInBackground) {
          _wasStreamingInBackground = true;
          _appBackgroundCount += 1;
          _lastBackgroundedAt = DateTime.now();
          _publishActiveState();
        }
      }
    }
  }

  Future<void> createAndConnect({
    required String title,
    required String languageCode,
  }) async {
    await _closeClient();
    _clearRuntime();

    final trimmedTitle = title.trim();
    final normalizedLanguage = _normalizeLanguageCode(languageCode);

    if (trimmedTitle.isEmpty) {
      state = const LiveFailed(errorMessage: 'Meeting title is required.');
      return;
    }
    if (!_isSupportedLanguage(normalizedLanguage)) {
      state = const LiveFailed(errorMessage: 'Select a supported language.');
      return;
    }

    final authSession = ref.read(currentSessionProvider);
    if (authSession == null) {
      state = const LiveFailed(
        errorMessage: 'Authentication session missing. Please log in again.',
      );
      return;
    }

    try {
      state = LiveCreatingSession(languageCode: normalizedLanguage);
      final startResult = await ref
          .read(liveSessionRepositoryProvider)
          .createLiveSession(
            title: trimmedTitle,
            languageCode: normalizedLanguage,
          );

      _meetingId = startResult.meetingId;
      _sessionId = startResult.sessionId;
      _languageCode = startResult.languageCode;
      _invalidateLiveData();

      state = LiveConnecting(
        meetingId: startResult.meetingId,
        sessionId: startResult.sessionId,
        languageCode: startResult.languageCode,
      );

      final openSession = ref.read(currentSessionProvider);
      final accessToken = openSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError(
          'Authentication session missing. Please log in again.',
        );
      }

      final webSocketUri = buildLiveTranscriptionWebSocketUri(
        backendBaseUrl: Env.backendUrl,
        sessionId: startResult.sessionId,
        languageCode: startResult.languageCode,
        accessToken: accessToken,
      );

      final client = await LiveWebSocketClient.connect(webSocketUri);
      _client = client;
      _webSocketStatus = 'connected';
      _captureStatus = 'not started';
      _eventSubscription = client.events.listen(
        _handleEvent,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );

      state = _readyState();
    } catch (error) {
      await _closeClient();
      _setFailed(_messageForError(error), error);
    }
  }

  Future<void> startAndroidMixedLive({
    required String title,
    required String languageCode,
  }) async {
    await _stopAndroidCapture();
    await _closeClient();
    _clearRuntime();

    final trimmedTitle = title.trim();
    final normalizedLanguage = _normalizeLanguageCode(languageCode);

    if (trimmedTitle.isEmpty) {
      state = const LiveFailed(errorMessage: 'Meeting title is required.');
      return;
    }
    if (!_isSupportedLanguage(normalizedLanguage)) {
      state = const LiveFailed(errorMessage: 'Select a supported language.');
      return;
    }

    final authSession = ref.read(currentSessionProvider);
    if (authSession == null) {
      state = const LiveFailed(
        errorMessage: 'Authentication session missing. Please log in again.',
      );
      return;
    }

    try {
      state = LiveCreatingSession(languageCode: normalizedLanguage);
      final startResult = await ref
          .read(liveSessionRepositoryProvider)
          .createLiveSession(
            title: trimmedTitle,
            languageCode: normalizedLanguage,
          );

      _meetingId = startResult.meetingId;
      _sessionId = startResult.sessionId;
      _languageCode = startResult.languageCode;
      _invalidateLiveData();

      _webSocketStatus = 'connecting';
      _captureStatus = 'not started';
      state = _connectingState();

      final openSession = ref.read(currentSessionProvider);
      final accessToken = openSession?.accessToken;
      if (accessToken == null || accessToken.isEmpty) {
        throw StateError(
          'Authentication session missing. Please log in again.',
        );
      }

      final webSocketUri = buildLiveTranscriptionWebSocketUri(
        backendBaseUrl: Env.backendUrl,
        sessionId: startResult.sessionId,
        languageCode: startResult.languageCode,
        accessToken: accessToken,
      );

      final client = await LiveWebSocketClient.connect(webSocketUri);
      _client = client;
      _webSocketStatus = 'connected';
      _eventSubscription = client.events.listen(
        _handleEvent,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );

      _captureStatus = 'requesting permissions';
      state = _startingCaptureState();
      await _prepareAndroidMixedCapture();

      _captureStatus = 'listening for PCM';
      await _subscribeToMixedPcm();

      _captureStatus = 'starting';
      state = _startingCaptureState();
      await _androidCapturePlatform.startCapture(
        const LiveCaptureConfig(
          captureSystemAudio: true,
          captureMicrophone: true,
          enableEchoCanceler: true,
          enableNoiseSuppressor: true,
          enableAutomaticGainControl: true,
          enableMicDucking: true,
        ),
      );

      _markCaptureStarted();
      _captureStatus = 'streaming';
      _webSocketStatus = 'streaming';
      state = _streamingState();
    } catch (error) {
      await _stopAndroidCapture();
      await _closeClient();
      _setFailed(_messageForError(error), error);
    }
  }

  Future<void> stop() async {
    final activeStop = _stopCompleter;
    if (activeStop != null) {
      await activeStop.future;
      return;
    }

    final client = _client;
    if (client == null) {
      return;
    }
    if (_meetingId == null || _sessionId == null || _languageCode == null) {
      await _closeClient();
      state = const LiveFailed(errorMessage: 'Live session is incomplete.');
      return;
    }

    final stopCompleter = Completer<void>();
    _stopCompleter = stopCompleter;
    _markCaptureStopped();
    _isPaused = false;
    _webSocketStatus = 'stopping';
    _captureStatus = 'stopping';
    state = _stoppingState();
    final doneCompleter = Completer<LiveDoneEvent>();
    _doneCompleter = doneCompleter;

    try {
      await _stopAndroidCapture();
      _sendStopOnce(client);
      final doneEvent = await doneCompleter.future.timeout(
        kLiveStopDoneTimeout,
      );
      await _closeClient();
      _webSocketStatus = 'closed';
      _captureStatus = 'stopped';
      state = _doneState(doneEvent: doneEvent);
      _invalidateLiveData();
    } on TimeoutException {
      _warnings = List.unmodifiable(<String>[
        ..._warnings,
        'Backend did not finish finalizing in time. The meeting may update shortly.',
      ]);
      await _closeClient();
      _webSocketStatus = 'closed';
      _captureStatus = 'stopped';
      state = _doneState();
      _invalidateLiveData();
    } catch (error) {
      await _closeClient();
      _webSocketStatus = 'failed';
      _captureStatus = 'stopped';
      _setFailed(_messageForError(error), error);
    } finally {
      _doneCompleter = null;
      if (!stopCompleter.isCompleted) {
        stopCompleter.complete();
      }
      if (identical(_stopCompleter, stopCompleter)) {
        _stopCompleter = null;
      }
    }
  }

  void pause() {
    if (_isPaused || state is LivePaused) {
      return;
    }
    if (state is! LiveStreaming) {
      return;
    }
    final pausedAt = DateTime.now();
    _isPaused = true;
    _pauseStartedAt ??= pausedAt;
    _logLive('LIVE_PAUSE', 'pause requested', {
      'pausedAt': pausedAt.toIso8601String(),
      'webSocketStatus': _webSocketStatus,
      'heartbeatIntervalSeconds': _pausedHeartbeatInterval.inSeconds,
    });
    _logLive('LIVE_WS', 'current websocket state at pause', {
      'webSocketStatus': _webSocketStatus,
      'isClosed': _client?.isClosed ?? true,
    });
    _startPausedHeartbeat();
    state = _pausedState();
  }

  void resume() {
    if (_resumeCompleter != null) {
      _logLive('LIVE_RESUME', 'duplicate resume prevented', {
        'webSocketStatus': _webSocketStatus,
      });
      return;
    }
    if (!_isPaused && state is! LivePaused) {
      return;
    }
    if (_meetingId == null || _sessionId == null || _languageCode == null) {
      return;
    }
    unawaited(_resume());
  }

  Future<void> _resume() async {
    final resumeCompleter = Completer<void>();
    _resumeCompleter = resumeCompleter;
    final resumedAt = DateTime.now();
    final pausedDuration = _currentPausedDuration(resumedAt);
    _stopPausedHeartbeat();
    _finalizePauseDuration(resumedAt);
    _resumeCount += 1;
    _lastResumeAt = resumedAt;
    _pcmChunksSentAfterResume = 0;
    _lastPcmSentAfterResumeAt = null;
    _lastTranscriptAfterResumeAt = null;
    _isSendingAudioAfterResume = false;
    state = _resumingState();

    try {
      _logLive('LIVE_RESUME', 'resume requested', {
        'resumedAt': resumedAt.toIso8601String(),
        'pausedDurationSeconds': pausedDuration.inSeconds,
        'webSocketStatusBeforeResume': _webSocketStatus,
      });
      _logLive('LIVE_WS', 'websocket state before resume', {
        'webSocketStatus': _webSocketStatus,
        'isClosed': _client?.isClosed ?? true,
      });
      final reconnected = await _ensureWebSocketReadyForResume();
      final nativeRunning = await _isNativeCaptureRunningForResume();
      if (!nativeRunning) {
        await _reinitializeNativeCaptureForResume();
      } else {
        _logLive(
          'LIVE_NATIVE_CAPTURE',
          'duplicate native service prevented on resume',
        );
      }
      _isPaused = false;
      _webSocketStatus = 'streaming';
      _captureStatus = 'streaming';
      _logLive('LIVE_RESUME', 'resume ready', {
        'webSocketReconnected': reconnected,
        'nativeCaptureReinitialized': !nativeRunning,
      });
      if (state is LiveResuming) {
        state = _streamingState();
      }
    } catch (error) {
      _logLive('LIVE_RESUME', 'resume failed', {
        'errorType': error.runtimeType.toString(),
      });
      await _failAfterCleanup(
        'Could not resume transcription. Please stop and start a new capture.',
        error,
        webSocketStatus: 'failed',
      );
      if (!resumeCompleter.isCompleted) {
        resumeCompleter.complete();
      }
      if (identical(_resumeCompleter, resumeCompleter)) {
        _resumeCompleter = null;
      }
      return;
    }

    if (!resumeCompleter.isCompleted) {
      resumeCompleter.complete();
    }
    if (identical(_resumeCompleter, resumeCompleter)) {
      _resumeCompleter = null;
    }
  }

  Future<bool> _ensureWebSocketReadyForResume() async {
    final client = _client;
    final needsReconnect =
        client == null ||
        client.isClosed ||
        _webSocketStatus == 'closed' ||
        _webSocketStatus == 'failed';

    if (!needsReconnect) {
      _logLive('LIVE_WS', 'duplicate websocket prevented on resume', {
        'webSocketStatus': _webSocketStatus,
      });
      return false;
    }

    _logLive('LIVE_WS', 'reconnecting websocket for resume', {
      'previousWebSocketStatus': _webSocketStatus,
    });
    await _closeClient();

    final sessionId = _sessionId;
    final languageCode = _languageCode;
    if (sessionId == null || languageCode == null) {
      throw StateError('Live session is incomplete.');
    }

    final openSession = ref.read(currentSessionProvider);
    final accessToken = openSession?.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('Authentication session missing. Please log in again.');
    }

    final webSocketUri = buildLiveTranscriptionWebSocketUri(
      backendBaseUrl: Env.backendUrl,
      sessionId: sessionId,
      languageCode: languageCode,
      accessToken: accessToken,
    );
    final nextClient = await LiveWebSocketClient.connect(webSocketUri);
    _client = nextClient;
    _eventSubscription = nextClient.events.listen(
      _handleEvent,
      onError: _handleWebSocketError,
      onDone: _handleWebSocketDone,
    );
    _webSocketStatus = 'connected';
    _logLive('LIVE_WS', 'websocket reconnected for resume');
    return true;
  }

  Future<bool> _isNativeCaptureRunningForResume() async {
    if (!Platform.isAndroid) {
      return true;
    }
    try {
      final running = await _androidCapturePlatform.isCaptureRunning();
      _logLive('LIVE_NATIVE_CAPTURE', 'native capture state before resume', {
        'running': running,
      });
      return running;
    } catch (error) {
      _logLive('LIVE_NATIVE_CAPTURE', 'native capture state check failed', {
        'errorType': error.runtimeType.toString(),
      });
      return true;
    }
  }

  Future<void> _reinitializeNativeCaptureForResume() async {
    if (!Platform.isAndroid) {
      return;
    }
    _logLive('LIVE_NATIVE_CAPTURE', 'reinitializing native capture for resume');
    _captureStatus = 'requesting permissions';
    state = _resumingState();
    await _prepareAndroidMixedCapture();
    await _subscribeToMixedPcm();
    _captureStatus = 'starting';
    state = _resumingState();
    await _androidCapturePlatform.startCapture(
      const LiveCaptureConfig(
        captureSystemAudio: true,
        captureMicrophone: true,
        enableEchoCanceler: true,
        enableNoiseSuppressor: true,
        enableAutomaticGainControl: true,
        enableMicDucking: true,
      ),
    );
    _logLive('LIVE_NATIVE_CAPTURE', 'native capture reinitialized for resume');
  }

  Future<void> discard() async {
    await _stopAndroidCapture();
    await _closeClient();
    _clearRuntime();
    state = const LiveIdle();
    _invalidateLiveData();
  }

  void reset() {
    unawaited(_stopAndroidCapture());
    unawaited(_closeClient());
    _clearRuntime();
    state = const LiveIdle();
  }

  void _handleEvent(LiveBackendEvent event) {
    final now = DateTime.now();
    _lastBackendEventAt = now;
    switch (event) {
      case LiveTranscriptEvent():
        if (_isPaused || state is LivePaused) {
          _logLive('LIVE_PAUSE', 'transcript event ignored while paused', {
            'isFinal': event.isFinal,
          });
          return;
        }
        _lastTranscriptEventAt = now;
        if (_lastResumeAt != null && !now.isBefore(_lastResumeAt!)) {
          _lastTranscriptAfterResumeAt = now;
        }
        _transcriptLines = mergeLiveTranscriptEvent(
          lines: _transcriptLines,
          event: event,
        );
        _publishActiveState();
      case LiveMessageEvent():
        _handleMessageEvent(event);
      case LiveDoneEvent():
        _handleDoneEvent(event);
      case LiveUnknownEvent():
        _messages = List.unmodifiable(<String>[
          ..._messages,
          'Received unsupported live transcription event.',
        ]);
        _publishActiveState();
    }
  }

  void _handleMessageEvent(LiveMessageEvent event) {
    final message = event.message.trim().isEmpty
        ? 'Live transcription message received.'
        : event.message.trim();

    switch (event.eventType) {
      case LiveBackendEventType.warning:
        _warnings = List.unmodifiable(<String>[..._warnings, message]);
        _publishActiveState();
      case LiveBackendEventType.info:
        _messages = List.unmodifiable(<String>[..._messages, message]);
        _publishActiveState();
      case LiveBackendEventType.error:
        _messages = List.unmodifiable(<String>[..._messages, message]);
        final completer = _doneCompleter;
        if (completer != null && !completer.isCompleted) {
          completer.completeError(StateError(message));
          return;
        }
        unawaited(
          _failAfterCleanup(
            message,
            StateError(message),
            webSocketStatus: 'failed',
          ),
        );
      case LiveBackendEventType.transcript ||
          LiveBackendEventType.done ||
          LiveBackendEventType.unknown:
        _publishActiveState();
    }
  }

  void _handleDoneEvent(LiveDoneEvent event) {
    final completer = _doneCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(event);
      return;
    }

    unawaited(_finishWithDone(event));
  }

  void _handleWebSocketError(Object error, StackTrace stackTrace) {
    final completer = _doneCompleter;
    if (state is LiveStopping && completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
      return;
    }
    final failedWhilePaused = state is LivePaused || _isPaused;
    if (failedWhilePaused) {
      _webSocketStatus = 'closed';
      _stopPausedHeartbeat();
      _logLive('LIVE_WS', 'websocket error while paused', {
        'pausedDurationSeconds': _currentPausedDuration().inSeconds,
        'errorType': error.runtimeType.toString(),
      });
      _publishActiveState();
      return;
    }
    unawaited(
      _failAfterCleanup(
        _connectionLostMessage(failedWhilePaused: failedWhilePaused),
        error,
        webSocketStatus: 'failed',
      ),
    );
  }

  void _handleWebSocketDone() {
    final current = state;
    if (current is LiveIdle ||
        current is LiveStopping ||
        current is LiveDone ||
        current is LiveFailed) {
      return;
    }
    final failedWhilePaused = current is LivePaused || _isPaused;
    if (failedWhilePaused) {
      _webSocketStatus = 'closed';
      _stopPausedHeartbeat();
      _logLive('LIVE_WS', 'websocket closed while paused', {
        'pausedDurationSeconds': _currentPausedDuration().inSeconds,
      });
      _publishActiveState();
      return;
    }
    final message = _connectionLostMessage(
      failedWhilePaused: failedWhilePaused,
    );
    unawaited(
      _failAfterCleanup(
        message,
        StateError(message),
        webSocketStatus: 'failed',
      ),
    );
  }

  Future<void> _prepareAndroidMixedCapture() async {
    final environment = await _androidCapturePlatform
        .getAndroidCaptureEnvironment();
    if (!environment.isAndroid || !environment.isSupported) {
      throw StateError(
        'Android 10 or newer is required for mixed audio capture.',
      );
    }

    final microphoneStatus = await Permission.microphone.request();
    if (!microphoneStatus.isGranted) {
      throw StateError(
        'Microphone permission is required for live transcription.',
      );
    }

    if (environment.requiresNotificationRuntimePermission) {
      final notificationStatus = await Permission.notification.request();
      if (!notificationStatus.isGranted) {
        throw StateError(
          'Notification permission is required for the live capture foreground service.',
        );
      }
    }

    final projection = await _androidCapturePlatform.requestProjection();
    if (!projection.granted) {
      throw StateError(
        projection.message ?? 'MediaProjection permission was denied.',
      );
    }
  }

  Future<void> _subscribeToMixedPcm() async {
    await _ensureCaptureStatusSubscription();
    await _pcmSubscription?.cancel();
    _pcmSubscription = _androidCapturePlatform.pcmFrames.listen(
      _handlePcmFrame,
      onError: (Object error) {
        _pcmChunksDropped += 1;
        _warnings = List.unmodifiable(<String>[
          ..._warnings,
          'Mixed PCM stream failed: ${_messageForError(error)}',
        ]);
        _publishActiveState();
      },
    );
  }

  Future<void> _ensureCaptureStatusSubscription() async {
    _captureStatusSubscription ??= _androidCapturePlatform.statusEvents.listen(
      (event) {
        final status = event.status;
        if (status != null && status.isNotEmpty) {
          _captureStatus = status;
        }
        if (event.code == 'mixedPcmFrameDroppedNoListener') {
          _pcmChunksDropped += 1;
        }
        if (event.eventType == LiveCaptureEventType.warning) {
          final message = event.message?.trim();
          if (message != null && message.isNotEmpty) {
            _addWarning(message, publish: false);
          }
        }
        if (event.eventType == LiveCaptureEventType.audioLevel) {
          _handleAudioLevelEvent(event);
          return;
        }
        if (event.eventType == LiveCaptureEventType.error) {
          _handleNativeCaptureError(event);
          return;
        }
        if (event.eventType == LiveCaptureEventType.stopped ||
            event.status == 'serviceStopped') {
          _handleNativeCaptureStopped(event);
          return;
        }
        _publishActiveState();
      },
      onError: (Object error) {
        _addWarning(
          'Android capture status stream failed: ${_messageForError(error)}',
        );
      },
    );
  }

  void _handlePcmFrame(Uint8List bytes) {
    if (bytes.isEmpty) {
      return;
    }

    final client = _client;
    if (_isPaused || state is LivePaused) {
      _pcmChunksSkippedWhilePaused += 1;
      _lastPcmChunkBytes = bytes.length;
      _publishPcmMetrics();
      return;
    }

    final canSend =
        client != null &&
        !client.isClosed &&
        state is! LiveStopping &&
        state is! LiveDone &&
        state is! LiveFailed;
    if (!canSend) {
      _pcmChunksDropped += 1;
      _lastPcmChunkBytes = bytes.length;
      _publishPcmMetrics();
      if (client == null || client.isClosed) {
        _logLive(
          'LIVE_AUDIO_CHUNK',
          'real audio chunk blocked by closed websocket',
          {'webSocketStatus': _webSocketStatus},
        );
      }
      return;
    }

    try {
      final isFirstRealChunkAfterResume =
          _lastResumeAt != null && _pcmChunksSentAfterResume == 0;
      client.sendBinary(bytes);
      _pcmChunksSent += 1;
      _lastPcmChunkBytes = bytes.length;
      final now = DateTime.now();
      _lastPcmSentAt = now;
      if (_lastResumeAt != null && !now.isBefore(_lastResumeAt!)) {
        _pcmChunksSentAfterResume += 1;
        _lastPcmSentAfterResumeAt = now;
        _isSendingAudioAfterResume = true;
        if (isFirstRealChunkAfterResume) {
          _logLive(
            'LIVE_AUDIO_CHUNK',
            'first real audio chunk after resume sent',
            {'sentAt': now.toIso8601String(), 'bytes': bytes.length},
          );
        }
      }
    } catch (error) {
      _pcmChunksDropped += 1;
      _logLive('LIVE_AUDIO_CHUNK', 'real audio chunk send failed', {
        'errorType': error.runtimeType.toString(),
      });
      _warnings = List.unmodifiable(<String>[
        ..._warnings,
        'PCM chunk dropped because WebSocket was not ready.',
      ]);
    }
    _publishPcmMetrics();
  }

  void _publishPcmMetrics({bool force = false}) {
    final now = DateTime.now();
    final lastPublished = _lastPcmMetricsPublishedAt;
    if (!force &&
        lastPublished != null &&
        now.difference(lastPublished) < const Duration(milliseconds: 250)) {
      return;
    }
    _lastPcmMetricsPublishedAt = now;
    _publishActiveState();
  }

  void _handleAudioLevelEvent(LiveCaptureEvent event) {
    final source = event.source;
    if (_audioLevelSource == 'mixed' && source != 'mixed') {
      return;
    }

    final level = (event.level ?? 0).clamp(0.0, 1.0).toDouble();
    _audioLevel = level;
    _hasAudioLevel = true;
    _isAudioDetected = !(event.isSilent ?? level < 0.01);
    _audioLevelSource = source;
    _publishActiveState();
  }

  Future<void> _finishWithDone(LiveDoneEvent event) async {
    if (state is LiveDone || state is LiveFailed) {
      return;
    }
    _markCaptureStopped();
    await _stopAndroidCapture();
    await _closeClient();
    _isPaused = false;
    _webSocketStatus = 'closed';
    _captureStatus = 'stopped';
    state = _doneState(doneEvent: event);
    _doneCompleter = null;
    _invalidateLiveData();
  }

  Future<void> _failAfterCleanup(
    String message,
    Object? error, {
    bool sendStop = false,
    String webSocketStatus = 'closed',
  }) async {
    if (_failureCleanupStarted || state is LiveDone || state is LiveFailed) {
      return;
    }
    _failureCleanupStarted = true;
    _markCaptureStopped();

    final client = _client;
    if (sendStop && client != null) {
      try {
        _sendStopOnce(client);
      } catch (_) {
        // The socket is already failing; cleanup continues below.
      }
    }

    await _stopAndroidCapture();
    await _closeClient();
    _isPaused = false;
    _webSocketStatus = webSocketStatus;
    _captureStatus = 'stopped';
    _setFailed(message, error);
    _invalidateLiveData();

    final completer = _doneCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error ?? StateError(message));
    }
  }

  void _handleNativeCaptureError(LiveCaptureEvent event) {
    final message = _messageForNativeCaptureEvent(
      event,
      fallback: 'Android live capture failed.',
    );
    if (state is LiveStopping) {
      _addWarning(message);
      return;
    }
    unawaited(
      _failAfterCleanup(
        message,
        StateError(message),
        sendStop: true,
        webSocketStatus: 'closed',
      ),
    );
  }

  void _handleNativeCaptureStopped(LiveCaptureEvent event) {
    _captureStatus = 'stopped';
    if (state is LiveIdle ||
        state is LiveStopping ||
        state is LiveDone ||
        state is LiveFailed ||
        _captureStopRequested) {
      _publishActiveState();
      return;
    }

    if (state is LivePaused || _isPaused) {
      _captureStatus = 'stopped';
      _logLive('LIVE_NATIVE_CAPTURE', 'native capture stopped while paused', {
        'pausedDurationSeconds': _currentPausedDuration().inSeconds,
      });
      _publishActiveState();
      return;
    }

    final reason = event.message?.trim().isNotEmpty == true
        ? event.message!.trim()
        : event.code?.trim();
    final detail = reason == null || reason.isEmpty
        ? 'Android live capture stopped unexpectedly.'
        : 'Android live capture stopped unexpectedly: $reason.';
    unawaited(
      _failAfterCleanup(
        detail,
        StateError(detail),
        sendStop: true,
        webSocketStatus: 'closed',
      ),
    );
  }

  void _sendStopOnce(LiveWebSocketClient client) {
    if (_stopMessageSent) {
      return;
    }
    _stopMessageSent = true;
    client.sendStop();
  }

  void _markCaptureStarted() {
    final now = DateTime.now();
    _captureStartedAt ??= now;
    _captureStoppedAt = null;
    _pausedDuration = Duration.zero;
    _pauseStartedAt = null;
    _lastTranscriptEventAt = null;
    _lastPcmSentAt = null;
    _lastBackendEventAt = null;
    _longPauseNoticeAdded = false;
    _longPauseWarningAdded = false;
    _startDurationTimer();
  }

  void _markCaptureStopped() {
    if (_captureStartedAt == null) {
      return;
    }
    _stopPausedHeartbeat();
    final now = DateTime.now();
    _finalizePauseDuration(now);
    _captureStoppedAt ??= now;
    _stopDurationTimer();
  }

  void _finalizePauseDuration([DateTime? at]) {
    final pauseStartedAt = _pauseStartedAt;
    if (pauseStartedAt == null) {
      return;
    }
    final now = at ?? DateTime.now();
    final elapsed = now.difference(pauseStartedAt);
    if (!elapsed.isNegative) {
      _pausedDuration += elapsed;
    }
    _pauseStartedAt = null;
  }

  Duration _currentTotalDuration([DateTime? at]) {
    final startedAt = _captureStartedAt;
    if (startedAt == null) {
      return Duration.zero;
    }
    final end = _captureStoppedAt ?? at ?? DateTime.now();
    final duration = end.difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  Duration _currentPausedDuration([DateTime? at]) {
    final pauseStartedAt = _pauseStartedAt;
    if (!_isPaused || pauseStartedAt == null) {
      return _pausedDuration;
    }
    final now = at ?? DateTime.now();
    final currentPause = now.difference(pauseStartedAt);
    if (currentPause.isNegative) {
      return _pausedDuration;
    }
    return _pausedDuration + currentPause;
  }

  Duration _currentActiveDuration([DateTime? at]) {
    final now = at ?? DateTime.now();
    final active = _currentTotalDuration(now) - _currentPausedDuration(now);
    return active.isNegative ? Duration.zero : active;
  }

  void _startDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshLongPauseWarnings(publish: false);
      _publishActiveState();
    });
  }

  void _stopDurationTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  void _startPausedHeartbeat() {
    if (_pausedHeartbeatTimer != null) {
      _logLive('LIVE_HEARTBEAT', 'duplicate heartbeat loop prevented');
      return;
    }
    _logLive('LIVE_HEARTBEAT', 'paused heartbeat loop started', {
      'intervalSeconds': _pausedHeartbeatInterval.inSeconds,
    });
    _sendPausedHeartbeat();
    _pausedHeartbeatTimer = Timer.periodic(
      _pausedHeartbeatInterval,
      (_) => _sendPausedHeartbeat(),
    );
  }

  void _stopPausedHeartbeat() {
    _pausedHeartbeatTimer?.cancel();
    _pausedHeartbeatTimer = null;
  }

  void _sendPausedHeartbeat() {
    if (!_isPaused && state is! LivePaused) {
      return;
    }
    if (state is LiveStopping || state is LiveDone || state is LiveFailed) {
      return;
    }
    final client = _client;
    final sessionId = _sessionId;
    if (client == null || sessionId == null || client.isClosed) {
      _webSocketStatus = 'closed';
      _logLive(
        'LIVE_HEARTBEAT',
        'paused heartbeat skipped because websocket is closed',
        {'webSocketStatus': _webSocketStatus},
      );
      _stopPausedHeartbeat();
      _publishActiveState();
      return;
    }

    try {
      client.sendPausedHeartbeat(sessionId: sessionId);
      final now = DateTime.now();
      _pausedHeartbeatCount += 1;
      _lastPausedHeartbeatAt = now;
      _logLive('LIVE_HEARTBEAT', 'paused heartbeat sent', {
        'sentAt': now.toIso8601String(),
        'count': _pausedHeartbeatCount,
      });
      _publishActiveState();
    } catch (error) {
      _webSocketStatus = 'closed';
      _stopPausedHeartbeat();
      _logLive('LIVE_HEARTBEAT', 'paused heartbeat send failed', {
        'errorType': error.runtimeType.toString(),
      });
      _publishActiveState();
    }
  }

  void _refreshLongPauseWarnings({bool publish = true}) {
    if (!_isPaused && state is! LivePaused) {
      return;
    }
    final pausedDuration = _currentPausedDuration();
    var changed = false;
    if (!_longPauseNoticeAdded && pausedDuration >= _longPauseNoticeDuration) {
      _longPauseNoticeAdded = true;
      _addWarning(_longPauseNotice, publish: false);
      changed = true;
    }
    if (!_longPauseWarningAdded &&
        pausedDuration >= _longPauseWarningDuration) {
      _longPauseWarningAdded = true;
      _addWarning(_longPauseWarning, publish: false);
      changed = true;
    }
    if (changed && publish) {
      _publishActiveState();
    }
  }

  String _connectionLostMessage({required bool failedWhilePaused}) {
    if (failedWhilePaused) {
      if (_currentPausedDuration() >= _longPauseNoticeDuration) {
        return 'Live connection ended during pause. Please start a new capture.';
      }
      return 'Connection lost while capture was paused. Please start again.';
    }
    if (_lastResumeAt != null && _lastTranscriptAfterResumeAt == null) {
      return 'Could not resume transcription. Please stop and start a new capture.';
    }
    return 'Connection lost. Capture stopped safely.';
  }

  LiveReadyNoCapture _readyState() {
    return LiveReadyNoCapture(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveConnecting _connectingState() {
    return LiveConnecting(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveStartingCapture _startingCaptureState() {
    return LiveStartingCapture(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveStreaming _streamingState() {
    return LiveStreaming(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LivePaused _pausedState() {
    return LivePaused(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveResuming _resumingState() {
    return LiveResuming(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveStopping _stoppingState() {
    return LiveStopping(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  LiveDone _doneState({LiveDoneEvent? doneEvent}) {
    return LiveDone(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
      finalTranscript: doneEvent?.transcript ?? '',
      usedGroqFallback: doneEvent?.usedGroqFallback ?? false,
    );
  }

  void _publishActiveState() {
    if (_meetingId == null || _sessionId == null || _languageCode == null) {
      return;
    }
    if (state is LiveStopping) {
      state = _stoppingState();
    } else if (state is LiveStartingCapture) {
      state = _startingCaptureState();
    } else if (state is LiveStreaming) {
      state = _streamingState();
    } else if (state is LivePaused) {
      state = _pausedState();
    } else if (state is LiveResuming) {
      state = _resumingState();
    } else if (state is! LiveDone && state is! LiveFailed) {
      state = _readyState();
    }
  }

  void _addWarning(String message, {bool publish = true}) {
    final trimmed = message.trim();
    if (trimmed.isEmpty || _warnings.contains(trimmed)) {
      return;
    }
    _warnings = List.unmodifiable(<String>[..._warnings, trimmed]);
    if (publish) {
      _publishActiveState();
    }
  }

  void _setFailed(String message, Object? error) {
    state = LiveFailed(
      errorMessage: message,
      error: error,
      meetingId: _meetingId,
      sessionId: _sessionId,
      languageCode: _languageCode,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
      webSocketStatus: _webSocketStatus,
      captureStatus: _captureStatus,
      pcmChunksSent: _pcmChunksSent,
      pcmChunksDropped: _pcmChunksDropped,
      lastPcmChunkBytes: _lastPcmChunkBytes,
      audioLevel: _audioLevel,
      hasAudioLevel: _hasAudioLevel,
      isAudioDetected: _isAudioDetected,
      isPaused: _isPaused,
      pcmChunksSkippedWhilePaused: _pcmChunksSkippedWhilePaused,
      captureStartedAt: _captureStartedAt,
      captureStoppedAt: _captureStoppedAt,
      activeDuration: _currentActiveDuration(),
      pausedDuration: _currentPausedDuration(),
      totalSessionDuration: _currentTotalDuration(),
      lastTranscriptEventAt: _lastTranscriptEventAt,
      lastPcmSentAt: _lastPcmSentAt,
      lastBackendEventAt: _lastBackendEventAt,
      appBackgroundCount: _appBackgroundCount,
      appForegroundReturnCount: _appForegroundReturnCount,
      lastBackgroundedAt: _lastBackgroundedAt,
      resumeCount: _resumeCount,
      lastResumeAt: _lastResumeAt,
      pcmChunksSentAfterResume: _pcmChunksSentAfterResume,
      lastPcmSentAfterResumeAt: _lastPcmSentAfterResumeAt,
      lastTranscriptAfterResumeAt: _lastTranscriptAfterResumeAt,
      isSendingAudioAfterResume: _isSendingAudioAfterResume,
      pausedHeartbeatCount: _pausedHeartbeatCount,
      lastPausedHeartbeatAt: _lastPausedHeartbeatAt,
    );
  }

  Future<void> _closeClient() async {
    final subscription = _eventSubscription;
    _eventSubscription = null;
    if (subscription != null) {
      await subscription.cancel();
    }

    final client = _client;
    _client = null;
    if (client != null) {
      try {
        await client.close();
      } catch (_) {
        // Best-effort cleanup; callers preserve the user-facing state.
      }
    }
  }

  Future<void> _stopAndroidCapture() async {
    final platform = _capturePlatform;
    if (platform != null && !_captureStopRequested) {
      try {
        _captureStopRequested = true;
        _captureStatus = 'stopping';
        await platform.stopCapture();
      } catch (_) {
        // Best-effort native teardown; callers preserve user-facing state.
      }
    }

    final pcmSubscription = _pcmSubscription;
    _pcmSubscription = null;
    if (pcmSubscription != null) {
      await pcmSubscription.cancel();
    }

    final captureStatusSubscription = _captureStatusSubscription;
    _captureStatusSubscription = null;
    if (captureStatusSubscription != null) {
      await captureStatusSubscription.cancel();
    }

    _captureStatus = 'stopped';
    _publishPcmMetrics(force: true);
  }

  Future<void> _dispose() async {
    _stopDurationTimer();
    _stopPausedHeartbeat();
    await _stopAndroidCapture();
    await _closeClient();
    try {
      await _capturePlatform?.dispose();
    } catch (_) {
      // Best-effort platform cleanup.
    }
  }

  void _clearRuntime() {
    _stopDurationTimer();
    _stopPausedHeartbeat();
    _meetingId = null;
    _sessionId = null;
    _languageCode = null;
    _transcriptLines = const <LiveTranscriptLine>[];
    _messages = const <String>[];
    _warnings = const <String>[];
    _doneCompleter = null;
    _stopCompleter = null;
    _resumeCompleter = null;
    _webSocketStatus = 'idle';
    _captureStatus = 'idle';
    _pcmChunksSent = 0;
    _pcmChunksDropped = 0;
    _pcmChunksSkippedWhilePaused = 0;
    _lastPcmChunkBytes = 0;
    _audioLevel = 0;
    _hasAudioLevel = false;
    _isAudioDetected = false;
    _audioLevelSource = null;
    _lastPcmMetricsPublishedAt = null;
    _stopMessageSent = false;
    _captureStopRequested = false;
    _failureCleanupStarted = false;
    _isPaused = false;
    _wasStreamingInBackground = false;
    _captureStartedAt = null;
    _captureStoppedAt = null;
    _pauseStartedAt = null;
    _lastTranscriptEventAt = null;
    _lastPcmSentAt = null;
    _lastBackendEventAt = null;
    _lastBackgroundedAt = null;
    _pausedDuration = Duration.zero;
    _appBackgroundCount = 0;
    _appForegroundReturnCount = 0;
    _longPauseNoticeAdded = false;
    _longPauseWarningAdded = false;
    _resumeCount = 0;
    _lastResumeAt = null;
    _pcmChunksSentAfterResume = 0;
    _lastPcmSentAfterResumeAt = null;
    _lastTranscriptAfterResumeAt = null;
    _isSendingAudioAfterResume = false;
    _pausedHeartbeatCount = 0;
    _lastPausedHeartbeatAt = null;
  }

  void _invalidateLiveData() {
    ref.invalidate(meetingsListProvider);
    ref.invalidate(liveLimitsProvider);
    final meetingId = _meetingId;
    if (meetingId != null) {
      ref.invalidate(meetingProvider(meetingId));
      ref.invalidate(sessionsProvider(meetingId));
    }
  }
}

String _normalizeLanguageCode(String value) {
  return value.trim().toLowerCase().split('-').first;
}

bool _isSupportedLanguage(String languageCode) {
  return supportedLanguages.any((language) => language.code == languageCode);
}

String _messageForError(Object error) {
  if (error is TimeoutException) {
    return 'WebSocket connection timed out. Check that the backend URL supports live transcription.';
  }
  if (error is SocketException) {
    return 'Backend is not reachable. Check your connection and backend URL.';
  }
  if (error is ArgumentError && error.message != null) {
    return error.message.toString();
  }
  if (error is StateError) {
    return error.message;
  }
  if (error is PlatformException) {
    final message = error.message ?? error.code;
    final lowerCode = error.code.toLowerCase();
    final lowerMessage = message.toLowerCase();
    if (lowerCode.contains('projection') && lowerMessage.contains('denied')) {
      return 'MediaProjection permission was denied.';
    }
    if (lowerCode.contains('permission') || lowerCode.contains('security')) {
      return 'Android live capture permission was denied.';
    }
    if (_looksLikeBackendReachabilityIssue(message)) {
      return 'Backend is not reachable. Check your connection and backend URL.';
    }
    return message;
  }
  final message = error.toString().trim();
  if (_looksLikeBackendReachabilityIssue(message)) {
    return 'Backend is not reachable. Check your connection and backend URL.';
  }
  return message.isEmpty ? 'Live recording failed.' : message;
}

String _messageForNativeCaptureEvent(
  LiveCaptureEvent event, {
  required String fallback,
}) {
  final message = event.message?.trim();
  if (message != null && message.isNotEmpty) {
    return message;
  }
  final code = event.code?.trim();
  if (code != null && code.isNotEmpty) {
    return 'Android live capture failed: $code.';
  }
  return fallback;
}

bool _looksLikeBackendReachabilityIssue(String message) {
  final lower = message.toLowerCase();
  return lower.contains('socketexception') ||
      lower.contains('connection refused') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection timed out') ||
      lower.contains('127.0.0.1') ||
      lower.contains('localhost');
}
