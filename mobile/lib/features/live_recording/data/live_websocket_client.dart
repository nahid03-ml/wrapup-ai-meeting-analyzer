import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:web_socket_channel/status.dart' as ws_status;
import 'package:web_socket_channel/web_socket_channel.dart';

import 'live_event.dart';
import 'live_session_models.dart';

class LiveWebSocketClient {
  LiveWebSocketClient._(this._channel);

  final WebSocketChannel _channel;
  Stream<LiveBackendEvent>? _events;

  static Future<LiveWebSocketClient> connect(
    Uri uri, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final channel = WebSocketChannel.connect(uri);
    await channel.ready.timeout(timeout);
    return LiveWebSocketClient._(channel);
  }

  Stream<LiveBackendEvent> get events {
    return _events ??= _channel.stream.map(parseLiveBackendSocketMessage);
  }

  int? get closeCode => _channel.closeCode;

  String? get closeReason => _channel.closeReason;

  bool get isClosed => closeCode != null;

  void sendStop() {
    _channel.sink.add(jsonEncode(LiveTranscriptionProtocol.stopControlMessage));
  }

  void sendPausedHeartbeat({required String sessionId}) {
    _channel.sink.add(
      encodeLivePausedHeartbeatControlMessage(sessionId: sessionId),
    );
  }

  void sendBinary(Uint8List bytes) {
    _channel.sink.add(bytes);
  }

  Future<void> close() async {
    await _channel.sink.close(ws_status.normalClosure);
  }
}

Map<String, String> livePausedHeartbeatControlMessage({
  required String sessionId,
}) {
  return <String, String>{
    'type': 'heartbeat',
    'state': 'paused',
    'session_id': sessionId,
  };
}

String encodeLivePausedHeartbeatControlMessage({required String sessionId}) {
  return jsonEncode(livePausedHeartbeatControlMessage(sessionId: sessionId));
}

LiveBackendEvent parseLiveBackendSocketMessage(dynamic message) {
  if (message is String) {
    try {
      final decoded = jsonDecode(message);
      if (decoded is Map) {
        return LiveBackendEvent.fromJson(_asStringKeyedMap(decoded));
      }
    } catch (_) {
      return const LiveMessageEvent(
        eventType: LiveBackendEventType.error,
        message: 'Malformed live transcription event.',
      );
    }
    return const LiveMessageEvent(
      eventType: LiveBackendEventType.error,
      message: 'Malformed live transcription event.',
    );
  }

  if (message is Uint8List) {
    return LiveUnknownEvent(<String, dynamic>{
      'type': LiveBackendEventType.unknown.wireValue,
      'binary_length': message.length,
    });
  }

  if (message is List<int>) {
    return LiveUnknownEvent(<String, dynamic>{
      'type': LiveBackendEventType.unknown.wireValue,
      'binary_length': message.length,
    });
  }

  return LiveUnknownEvent(<String, dynamic>{
    'type': LiveBackendEventType.unknown.wireValue,
  });
}

Map<String, dynamic> _asStringKeyedMap(Map<dynamic, dynamic> value) {
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}
