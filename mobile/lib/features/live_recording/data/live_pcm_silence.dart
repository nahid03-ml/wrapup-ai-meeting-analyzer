import 'dart:typed_data';

const kLivePcmSampleRateHz = 16000;
const kLivePcmBytesPerSample = 2;
const kLivePausedSilenceKeepAliveFrameDuration = Duration(milliseconds: 100);

Uint8List buildLivePcm16SilenceFrame({
  Duration duration = kLivePausedSilenceKeepAliveFrameDuration,
  int sampleRateHz = kLivePcmSampleRateHz,
}) {
  final sampleCount =
      sampleRateHz * duration.inMilliseconds ~/ Duration.millisecondsPerSecond;
  return Uint8List(sampleCount * kLivePcmBytesPerSample);
}
