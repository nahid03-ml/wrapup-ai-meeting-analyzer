import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/features/live_recording/application/live_transcript_line.dart';
import 'package:mobile/features/live_recording/data/live_event.dart';
import 'package:mobile/features/live_recording/data/live_websocket_client.dart';
import 'package:mobile/features/live_recording/data/live_websocket_url_builder.dart';

void main() {
  test('live websocket builder converts https base URL to wss URL', () {
    final uri = buildLiveTranscriptionWebSocketUri(
      backendBaseUrl: 'https://api.wrapup.test',
      sessionId: 'session-123',
      languageCode: 'en',
      accessToken: 'access-token',
    );

    expect(uri.scheme, 'wss');
    expect(uri.pathSegments, ['ws', 'live-transcription', 'session-123']);
    expect(uri.queryParameters['lang'], 'en');
    expect(uri.queryParameters['token'], 'access-token');
  });

  test('live websocket builder converts http base URL to ws URL', () {
    final uri = buildLiveTranscriptionWebSocketUri(
      backendBaseUrl: 'http://localhost:8000',
      sessionId: 'session-123',
      languageCode: 'es',
      accessToken: 'fresh-token',
    );

    expect(uri.scheme, 'ws');
    expect(uri.host, 'localhost');
    expect(uri.port, 8000);
    expect(uri.queryParameters, {'lang': 'es', 'token': 'fresh-token'});
  });

  test('backend transcript and done events parse from protocol JSON', () {
    final transcript = LiveBackendEvent.fromJson({
      'type': 'transcript',
      'text': 'hello',
      'speaker': 1,
      'is_final': true,
      'confidence': 0.91,
    });
    final done = LiveBackendEvent.fromJson({
      'type': 'done',
      'session_id': 'session-123',
      'transcript': 'hello',
      'used_groq_fallback': false,
    });

    expect(transcript, isA<LiveTranscriptEvent>());
    expect((transcript as LiveTranscriptEvent).isFinal, isTrue);
    expect(transcript.speaker, 1);
    expect(done, isA<LiveDoneEvent>());
    expect((done as LiveDoneEvent).sessionId, 'session-123');
    expect(done.usedGroqFallback, isFalse);
  });

  test('malformed websocket text becomes a safe error event', () {
    final event = parseLiveBackendSocketMessage('{not-json');

    expect(event, isA<LiveMessageEvent>());
    expect(event.type, 'error');
    expect((event as LiveMessageEvent).message, isNotEmpty);
  });

  test(
    'interim transcript lines update and finals replace trailing interim',
    () {
      final createdAt = DateTime.utc(2026, 4, 28);
      var lines = mergeLiveTranscriptEvent(
        lines: const [],
        event: const LiveTranscriptEvent(
          text: 'hello',
          speaker: 0,
          isFinal: false,
          confidence: 0.5,
        ),
        createdAt: createdAt,
      );

      lines = mergeLiveTranscriptEvent(
        lines: lines,
        event: const LiveTranscriptEvent(
          text: 'hello there',
          speaker: 0,
          isFinal: false,
          confidence: 0.7,
        ),
        createdAt: createdAt,
      );

      expect(lines, hasLength(1));
      expect(lines.single.text, 'hello there');
      expect(lines.single.isFinal, isFalse);

      lines = mergeLiveTranscriptEvent(
        lines: lines,
        event: const LiveTranscriptEvent(
          text: 'hello there',
          speaker: 0,
          isFinal: true,
          confidence: 0.92,
        ),
        createdAt: createdAt,
      );

      expect(lines, hasLength(1));
      expect(lines.single.text, 'hello there');
      expect(lines.single.isFinal, isTrue);
      expect(lines.single.createdAt, createdAt);
    },
  );

  test('paused heartbeat control message is safe text JSON', () {
    final encoded = encodeLivePausedHeartbeatControlMessage(
      sessionId: 'session-123',
    );
    final decoded = jsonDecode(encoded) as Map<String, dynamic>;

    expect(decoded, {
      'type': 'heartbeat',
      'state': 'paused',
      'session_id': 'session-123',
    });
    expect(encoded, isNot(contains('token')));
  });
}
