class LiveCaptureConfig {
  const LiveCaptureConfig({
    this.captureSystemAudio = true,
    this.captureMicrophone = true,
    this.sampleRateHz = 16000,
    this.channelCount = 1,
    this.bitsPerSample = 16,
    this.micGain = 0.8,
    this.systemGain = 0.8,
    this.enableEchoCanceler = true,
    this.enableNoiseSuppressor = true,
    this.enableAutomaticGainControl = false,
    this.enableMicDucking = true,
    this.micEchoDuckedGain = 0.25,
    this.systemActiveThreshold = 0.02,
    this.micSpeechThreshold = 0.04,
  });

  final bool captureSystemAudio;
  final bool captureMicrophone;
  final int sampleRateHz;
  final int channelCount;
  final int bitsPerSample;
  final double micGain;
  final double systemGain;
  final bool enableEchoCanceler;
  final bool enableNoiseSuppressor;
  final bool enableAutomaticGainControl;
  final bool enableMicDucking;
  final double micEchoDuckedGain;
  final double systemActiveThreshold;
  final double micSpeechThreshold;

  Map<String, Object?> toMethodChannelMap() => <String, Object?>{
    'captureSystemAudio': captureSystemAudio,
    'captureMicrophone': captureMicrophone,
    'sampleRateHz': sampleRateHz,
    'channelCount': channelCount,
    'bitsPerSample': bitsPerSample,
    'micGain': micGain,
    'systemGain': systemGain,
    'enableEchoCanceler': enableEchoCanceler,
    'enableNoiseSuppressor': enableNoiseSuppressor,
    'enableAutomaticGainControl': enableAutomaticGainControl,
    'enableMicDucking': enableMicDucking,
    'micEchoDuckedGain': micEchoDuckedGain,
    'systemActiveThreshold': systemActiveThreshold,
    'micSpeechThreshold': micSpeechThreshold,
  };
}
