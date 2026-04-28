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

  Future<AndroidCaptureEnvironment> getAndroidCaptureEnvironment() async {
    if (defaultTargetPlatform != TargetPlatform.android) {
      return const AndroidCaptureEnvironment(
        isAndroid: false,
        isSupported: false,
        supportsDeviceAudioCapture: false,
      );
    }
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'getAndroidCaptureEnvironment',
    );
    return AndroidCaptureEnvironment.fromMap(
      result ?? const <String, dynamic>{},
    );
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

class AndroidCaptureEnvironment {
  const AndroidCaptureEnvironment({
    required this.isAndroid,
    required this.isSupported,
    required this.supportsDeviceAudioCapture,
    this.sdkInt,
    this.isAndroid10Plus = false,
    this.isAndroid13Plus = false,
    this.isAndroid14Plus = false,
    this.requiresNotificationRuntimePermission = false,
    this.requiresForegroundServiceTypes = false,
  });

  final bool isAndroid;
  final int? sdkInt;
  final bool isAndroid10Plus;
  final bool isAndroid13Plus;
  final bool isAndroid14Plus;
  final bool isSupported;
  final bool requiresNotificationRuntimePermission;
  final bool requiresForegroundServiceTypes;
  final bool supportsDeviceAudioCapture;

  factory AndroidCaptureEnvironment.fromMap(Map<String, dynamic> map) {
    final sdkInt = _intOrNull(map['sdkInt']);
    return AndroidCaptureEnvironment(
      isAndroid: true,
      sdkInt: sdkInt,
      isAndroid10Plus: map['isAndroid10Plus'] == true,
      isAndroid13Plus: map['isAndroid13Plus'] == true,
      isAndroid14Plus: map['isAndroid14Plus'] == true,
      isSupported: map['isSupported'] == true,
      requiresNotificationRuntimePermission:
          map['requiresNotificationRuntimePermission'] == true,
      requiresForegroundServiceTypes:
          map['requiresForegroundServiceTypes'] == true,
      supportsDeviceAudioCapture: map['supportsDeviceAudioCapture'] == true,
    );
  }
}

int? _intOrNull(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
