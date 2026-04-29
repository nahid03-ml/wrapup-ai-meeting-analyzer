import 'dart:async';
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
const _backgroundWarning =
    'Live capture continued while the app was in the background.';

class LiveRecordingController extends Notifier<LiveRecordingState>
    with WidgetsBindingObserver {
  LiveWebSocketClient? _client;
  AndroidLiveCapturePlatform? _capturePlatform;
  StreamSubscription<LiveBackendEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _pcmSubscription;
  StreamSubscription? _captureStatusSubscription;
  Completer<LiveDoneEvent>? _doneCompleter;
  Completer<void>? _stopCompleter;

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
  int _lastPcmChunkBytes = 0;
  DateTime? _lastPcmMetricsPublishedAt;
  bool _stopMessageSent = false;
  bool _captureStopRequested = false;
  bool _failureCleanupStarted = false;
  bool _lifecycleObserverAttached = false;
  bool _wasStreamingInBackground = false;

  AndroidLiveCapturePlatform get _androidCapturePlatform {
    return _capturePlatform ??= AndroidLiveCapturePlatform();
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
        _addWarning(_backgroundWarning);
      }
      return;
    }

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (this.state is LiveStreaming) {
        _wasStreamingInBackground = true;
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
    switch (event) {
      case LiveTranscriptEvent():
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
    unawaited(
      _failAfterCleanup(
        _messageForError(error),
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
    unawaited(
      _failAfterCleanup(
        'Live connection closed before recording stopped.',
        StateError('Live connection closed before recording stopped.'),
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
    final canSend =
        client != null &&
        state is! LiveStopping &&
        state is! LiveDone &&
        state is! LiveFailed;
    if (!canSend) {
      _pcmChunksDropped += 1;
      _lastPcmChunkBytes = bytes.length;
      _publishPcmMetrics();
      return;
    }

    try {
      client.sendBinary(bytes);
      _pcmChunksSent += 1;
      _lastPcmChunkBytes = bytes.length;
    } catch (error) {
      _pcmChunksDropped += 1;
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

  Future<void> _finishWithDone(LiveDoneEvent event) async {
    if (state is LiveDone || state is LiveFailed) {
      return;
    }
    await _stopAndroidCapture();
    await _closeClient();
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
    await _stopAndroidCapture();
    await _closeClient();
    try {
      await _capturePlatform?.dispose();
    } catch (_) {
      // Best-effort platform cleanup.
    }
  }

  void _clearRuntime() {
    _meetingId = null;
    _sessionId = null;
    _languageCode = null;
    _transcriptLines = const <LiveTranscriptLine>[];
    _messages = const <String>[];
    _warnings = const <String>[];
    _doneCompleter = null;
    _stopCompleter = null;
    _webSocketStatus = 'idle';
    _captureStatus = 'idle';
    _pcmChunksSent = 0;
    _pcmChunksDropped = 0;
    _lastPcmChunkBytes = 0;
    _lastPcmMetricsPublishedAt = null;
    _stopMessageSent = false;
    _captureStopRequested = false;
    _failureCleanupStarted = false;
    _wasStreamingInBackground = false;
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
