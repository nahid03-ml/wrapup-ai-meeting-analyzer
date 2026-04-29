enum CaptureModeId {
  androidDeviceAudioMicBeta('androidDeviceAudioMicBeta');

  const CaptureModeId(this.value);

  final String value;
}

enum CaptureModeIcon { android }

class CaptureMode {
  const CaptureMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.limitations,
    required this.icon,
  });

  final CaptureModeId id;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String limitations;
  final CaptureModeIcon icon;
}

const androidLiveCaptureMode = CaptureMode(
  id: CaptureModeId.androidDeviceAudioMicBeta,
  title: 'Android device audio + microphone beta',
  subtitle:
      'Captures supported device audio through Android system capture permission and prepares microphone capture for later mixing.',
  statusLabel: 'Android beta',
  limitations: 'Some apps may block device audio capture.',
  icon: CaptureModeIcon.android,
);

const liveCaptureModes = <CaptureMode>[androidLiveCaptureMode];
