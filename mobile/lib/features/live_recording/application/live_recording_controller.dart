import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/languages/supported_languages.dart';
import '../../../core/providers/supabase_provider.dart';
import '../../meetings/application/meetings_provider.dart';
import '../data/live_event.dart';
import '../data/live_session_repository.dart';
import '../data/live_websocket_client.dart';
import '../data/live_websocket_url_builder.dart';
import 'live_limits_provider.dart';
import 'live_recording_state.dart';
import 'live_transcript_line.dart';

const kLiveStopDoneTimeout = Duration(seconds: 30);

class LiveRecordingController extends Notifier<LiveRecordingState> {
  LiveWebSocketClient? _client;
  StreamSubscription<LiveBackendEvent>? _eventSubscription;
  Completer<LiveDoneEvent>? _doneCompleter;

  String? _meetingId;
  String? _sessionId;
  String? _languageCode;
  List<LiveTranscriptLine> _transcriptLines = const <LiveTranscriptLine>[];
  List<String> _messages = const <String>[];
  List<String> _warnings = const <String>[];

  @override
  LiveRecordingState build() {
    ref.onDispose(() {
      unawaited(_dispose());
    });
    return const LiveIdle();
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
          .createLiveSession(title: trimmedTitle, languageCode: normalizedLanguage);

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
        throw StateError('Authentication session missing. Please log in again.');
      }

      final webSocketUri = buildLiveTranscriptionWebSocketUri(
        backendBaseUrl: Env.backendUrl,
        sessionId: startResult.sessionId,
        languageCode: startResult.languageCode,
        accessToken: accessToken,
      );

      final client = await LiveWebSocketClient.connect(webSocketUri);
      _client = client;
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

  Future<void> stop() async {
    final client = _client;
    if (client == null) {
      return;
    }
    if (_meetingId == null || _sessionId == null || _languageCode == null) {
      await _closeClient();
      state = const LiveFailed(errorMessage: 'Live session is incomplete.');
      return;
    }
    if (state is LiveStopping) {
      return;
    }

    state = _stoppingState();
    final doneCompleter = Completer<LiveDoneEvent>();
    _doneCompleter = doneCompleter;

    try {
      client.sendStop();
      final doneEvent = await doneCompleter.future.timeout(
        kLiveStopDoneTimeout,
      );
      await _closeClient();
      state = _doneState(doneEvent: doneEvent);
      _invalidateLiveData();
    } on TimeoutException {
      _warnings = List.unmodifiable(<String>[
        ..._warnings,
        'Recording stopped, but final processing may still be completing.',
      ]);
      await _closeClient();
      state = _doneState();
      _invalidateLiveData();
    } catch (error) {
      await _closeClient();
      _setFailed(_messageForError(error), error);
    } finally {
      _doneCompleter = null;
    }
  }

  Future<void> discard() async {
    await _closeClient();
    _clearRuntime();
    state = const LiveIdle();
    _invalidateLiveData();
  }

  void reset() {
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
        _setFailed(message, StateError(message));
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

    state = _doneState(doneEvent: event);
    unawaited(_closeClient());
    _invalidateLiveData();
  }

  void _handleWebSocketError(Object error, StackTrace stackTrace) {
    final completer = _doneCompleter;
    if (state is LiveStopping && completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
      return;
    }
    _setFailed('Live connection failed.', error);
  }

  void _handleWebSocketDone() {
    final current = state;
    if (current is LiveIdle ||
        current is LiveStopping ||
        current is LiveDone ||
        current is LiveFailed) {
      return;
    }
    _setFailed('Live connection closed before recording stopped.', null);
  }

  LiveReadyNoCapture _readyState() {
    return LiveReadyNoCapture(
      meetingId: _meetingId!,
      sessionId: _sessionId!,
      languageCode: _languageCode!,
      transcriptLines: List.unmodifiable(_transcriptLines),
      messages: List.unmodifiable(_messages),
      warnings: List.unmodifiable(_warnings),
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
    } else if (state is! LiveDone && state is! LiveFailed) {
      state = _readyState();
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

  Future<void> _dispose() async {
    await _closeClient();
  }

  void _clearRuntime() {
    _meetingId = null;
    _sessionId = null;
    _languageCode = null;
    _transcriptLines = const <LiveTranscriptLine>[];
    _messages = const <String>[];
    _warnings = const <String>[];
    _doneCompleter = null;
  }

  void _invalidateLiveData() {
    ref.invalidate(meetingsListProvider);
    ref.invalidate(liveLimitsProvider);
  }
}

String _normalizeLanguageCode(String value) {
  return value.trim().toLowerCase().split('-').first;
}

bool _isSupportedLanguage(String languageCode) {
  return supportedLanguages.any((language) => language.code == languageCode);
}

String _messageForError(Object error) {
  if (error is ArgumentError && error.message != null) {
    return error.message.toString();
  }
  if (error is StateError) {
    return error.message;
  }
  final message = error.toString().trim();
  return message.isEmpty ? 'Live recording failed.' : message;
}
