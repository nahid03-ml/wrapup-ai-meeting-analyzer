enum CaptureModeId {
  desktopSystemAudioMic('desktopSystemAudioMic'),
  androidDeviceAudioMicBeta('androidDeviceAudioMicBeta'),
  roomAudioFallback('roomAudioFallback');

  const CaptureModeId(this.value);

  final String value;
}

enum CaptureModeIcon {
  desktop,
  android,
  microphone,
}

class CaptureMode {
  const CaptureMode({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.limitations,
    required this.icon,
    required this.buttonLabel,
    required this.enabled,
  });

  final CaptureModeId id;
  final String title;
  final String subtitle;
  final String statusLabel;
  final String limitations;
  final CaptureModeIcon icon;
  final String buttonLabel;
  final bool enabled;
}

const liveCaptureModes = <CaptureMode>[
  CaptureMode(
    id: CaptureModeId.desktopSystemAudioMic,
    title: 'Desktop system audio + microphone',
    subtitle:
        'Recommended for Zoom, Meet, Teams and browser meetings on supported desktop devices.',
    statusLabel: 'Best quality · use desktop app',
    limitations: 'Windows first, macOS next. Uses supported OS-level capture paths.',
    icon: CaptureModeIcon.desktop,
    buttonLabel: 'Desktop capture coming soon',
    enabled: false,
  ),
  CaptureMode(
    id: CaptureModeId.androidDeviceAudioMicBeta,
    title: 'Android device audio + microphone beta',
    subtitle:
        'Requires device audio capture permission. Some apps may block device audio capture.',
    statusLabel: 'Coming next',
    limitations:
        'Android support will require a system capture prompt and may vary by meeting app.',
    icon: CaptureModeIcon.android,
    buttonLabel: 'Android beta coming soon',
    enabled: false,
  ),
  CaptureMode(
    id: CaptureModeId.roomAudioFallback,
    title: 'Room audio fallback',
    subtitle: 'Records through microphone, best when meeting audio plays on speaker.',
    statusLabel: 'Available later in Phase 6',
    limitations: 'Lower quality fallback for mobile when device audio capture is unavailable.',
    icon: CaptureModeIcon.microphone,
    buttonLabel: 'Room fallback coming soon',
    enabled: false,
  ),
];
