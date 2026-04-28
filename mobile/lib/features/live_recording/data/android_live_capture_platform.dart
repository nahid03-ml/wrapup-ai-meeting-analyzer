import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'live_capture_config.dart';
import 'live_capture_event.dart';

class AndroidLiveCapturePlatform {
  AndroidLiveCapturePlatform({
    MethodChannel? methodChannel,
    EventChannel? statusEventChannel,
    EventChannel? pcmEventChannel,
  }) : _methodChannel =
           methodChannel ?? const MethodChannel('wrapup/live_capture'),
       _statusEventChannel =
           statusEventChannel ??
           const EventChannel('wrapup/live_capture_status'),
       _pcmEventChannel =
           pcmEventChannel ?? const EventChannel('wrapup/live_capture_pcm');

  final MethodChannel _methodChannel;
  final EventChannel _statusEventChannel;
  final EventChannel _pcmEventChannel;

  Stream<LiveCaptureEvent>? _statusEvents;
  Stream<Uint8List>? _pcmFrames;

  Stream<LiveCaptureEvent> get statusEvents {
    return _statusEvents ??= _statusEventChannel
        .receiveBroadcastStream()
        .map(_captureEventFromDynamic);
  }

  Stream<Uint8List> get pcmFrames {
    return _pcmFrames ??= _pcmEventChannel
        .receiveBroadcastStream()
        .map(_pcmFrameFromDynamic)
        .where((frame) => frame.isNotEmpty);
  }

  Future<bool> isSupported() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    final supported = await _methodChannel.invokeMethod<bool>('isSupported');
    return supported ?? false;
  }

  Future<LiveProjectionResult> requestProjection() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return LiveProjectionResult.denied(
        'Android device audio capture is only available on Android.',
      );
    }

    try {
      final result = await _methodChannel.invokeMapMethod<String, dynamic>(
        'requestProjection',
      );
      return LiveProjectionResult.fromMap(result ?? const <String, dynamic>{});
    } on PlatformException catch (error) {
      return LiveProjectionResult.denied(
        error.message ?? 'MediaProjection request failed.',
      );
    }
  }

  Future<void> startCapture(LiveCaptureConfig config) async {
    await _methodChannel.invokeMethod<void>(
      'startCapture',
      config.toMethodChannelMap(),
    );
  }

  Future<void> stopCapture() async {
    await _methodChannel.invokeMethod<void>('stopCapture');
  }

  Future<void> dispose() async {
    await _methodChannel.invokeMethod<void>('dispose');
  }
}

LiveCaptureEvent _captureEventFromDynamic(dynamic value) {
  if (value is Map) {
    return LiveCaptureEvent.fromMap(_asStringKeyedMap(value));
  }
  return LiveCaptureEvent.unknown();
}

Uint8List _pcmFrameFromDynamic(dynamic value) {
  if (value is Uint8List) {
    return value;
  }
  if (value is ByteData) {
    return value.buffer.asUint8List(value.offsetInBytes, value.lengthInBytes);
  }
  if (value is List<int>) {
    return Uint8List.fromList(value);
  }
  return Uint8List(0);
}

Map<String, dynamic> _asStringKeyedMap(Map<dynamic, dynamic> value) {
  return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
}
