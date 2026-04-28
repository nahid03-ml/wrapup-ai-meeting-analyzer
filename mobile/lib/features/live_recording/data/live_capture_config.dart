class LiveCaptureConfig {
  const LiveCaptureConfig({
    this.captureSystemAudio = true,
    this.captureMicrophone = true,
    this.sampleRateHz = 16000,
    this.channelCount = 1,
    this.bitsPerSample = 16,
    this.micGain = 0.8,
    this.systemGain = 0.8,
  });

  final bool captureSystemAudio;
  final bool captureMicrophone;
  final int sampleRateHz;
  final int channelCount;
  final int bitsPerSample;
  final double micGain;
  final double systemGain;

  Map<String, Object?> toMethodChannelMap() => <String, Object?>{
    'captureSystemAudio': captureSystemAudio,
    'captureMicrophone': captureMicrophone,
    'sampleRateHz': sampleRateHz,
    'channelCount': channelCount,
    'bitsPerSample': bitsPerSample,
    'micGain': micGain,
    'systemGain': systemGain,
  };
}
