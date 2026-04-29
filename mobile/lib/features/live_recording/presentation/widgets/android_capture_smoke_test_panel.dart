import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/android_capture_smoke_test_provider.dart';
import '../../application/android_capture_smoke_test_state.dart';
import '../../data/live_capture_event.dart';

class AndroidCaptureSmokeTestPanel extends ConsumerStatefulWidget {
  const AndroidCaptureSmokeTestPanel({super.key});

  @override
  ConsumerState<AndroidCaptureSmokeTestPanel> createState() =>
      _AndroidCaptureSmokeTestPanelState();
}

class _AndroidCaptureSmokeTestPanelState
    extends ConsumerState<AndroidCaptureSmokeTestPanel> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref
            .read(androidCaptureSmokeTestControllerProvider.notifier)
            .checkEnvironment();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(androidCaptureSmokeTestControllerProvider);
    final controller = ref.read(
      androidCaptureSmokeTestControllerProvider.notifier,
    );

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.android_outlined, color: AppColors.cyan),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Android bridge smoke test',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (state.isChecking)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'These proofs check Android system playback, microphone capture, and local native mixing. They do not stream transcription yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusRow(label: 'Android version', value: state.versionBucketLabel),
          _StatusRow(
            label: 'Support',
            value: state.isSupported ? 'supported' : 'not supported',
          ),
          _StatusRow(
            label: 'Microphone permission',
            value: state.microphonePermissionStatus,
          ),
          _StatusRow(
            label: 'Notification permission',
            value: state.notificationPermissionStatus,
          ),
          _StatusRow(label: 'Projection', value: state.projectionStatus),
          _StatusRow(label: 'Service', value: state.serviceStatus),
          const SizedBox(height: AppSpacing.md),
          _SectionTitle(text: 'System playback proof'),
          _StatusRow(
            label: 'System playback',
            value: state.systemPlaybackStatus,
          ),
          _StatusRow(
            label: 'Read status',
            value: state.playbackReadStatus,
          ),
          _StatusRow(
            label: 'First frame',
            value: state.hasPlaybackFirstFrameRead ? 'yes' : 'no',
          ),
          if (state.latestReadResult != null)
            _StatusRow(
              label: 'Latest read',
              value: state.latestReadResult.toString(),
            ),
          if (state.systemAudioSampleRateHz != null)
            _StatusRow(
              label: 'AudioRecord rate',
              value: '${state.systemAudioSampleRateHz} Hz',
            ),
          if (state.audioRecordDetails != null)
            _StatusRow(
              label: 'AudioRecord',
              value: state.audioRecordDetails!,
            ),
          const SizedBox(height: AppSpacing.sm),
          _AudioLevelMeter(
            label: 'System audio level',
            level: state.systemAudioLevel,
            isSilent: state.isSystemAudioSilent,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionTitle(text: 'Microphone proof'),
          Text(
            'This checks microphone capture only. It does not mix mic with system audio yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(label: 'Microphone', value: state.micCaptureStatus),
          _StatusRow(label: 'Mic read', value: state.micReadStatus),
          _StatusRow(
            label: 'Mic first frame',
            value: state.hasMicFirstFrameRead ? 'yes' : 'no',
          ),
          if (state.latestMicReadResult != null)
            _StatusRow(
              label: 'Mic latest read',
              value: state.latestMicReadResult.toString(),
            ),
          if (state.micAudioSampleRateHz != null)
            _StatusRow(
              label: 'Mic AudioRecord rate',
              value: '${state.micAudioSampleRateHz} Hz',
            ),
          if (state.micAudioSource != null)
            _StatusRow(label: 'Mic source', value: state.micAudioSource!),
          _StatusRow(
            label: 'AEC',
            value: _effectLabel(
              state.microphoneAecAvailable,
              state.microphoneAecEnabled,
            ),
          ),
          _StatusRow(
            label: 'NoiseSuppressor',
            value: _effectLabel(
              state.microphoneNoiseSuppressorAvailable,
              state.microphoneNoiseSuppressorEnabled,
            ),
          ),
          _StatusRow(
            label: 'AGC',
            value: _effectLabel(
              state.microphoneAgcAvailable,
              state.microphoneAgcEnabled,
            ),
          ),
          if (state.micAudioRecordDetails != null)
            _StatusRow(
              label: 'Mic AudioRecord',
              value: state.micAudioRecordDetails!,
            ),
          const SizedBox(height: AppSpacing.sm),
          _AudioLevelMeter(
            label: 'Mic level',
            level: state.micAudioLevel,
            isSilent: state.isMicSilent,
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionTitle(text: 'Mixed audio proof'),
          Text(
            'This checks local native mixing only. It does not stream audio to transcription yet.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusRow(label: 'Mixed capture', value: state.mixedCaptureStatus),
          _StatusRow(label: 'Mixed read', value: state.mixedReadStatus),
          if (state.mixedAudioSampleRateHz != null)
            _StatusRow(
              label: 'Mixed sample rate',
              value: '${state.mixedAudioSampleRateHz} Hz',
            ),
          _StatusRow(
            label: 'Clipping count',
            value: state.mixedClippingCount.toString(),
          ),
          _StatusRow(
            label: 'Mic ducking',
            value: state.micDucked ? 'active' : 'inactive',
          ),
          if (state.effectiveMicGain != null)
            _StatusRow(
              label: 'Effective mic gain',
              value: _gainLabel(state.effectiveMicGain!),
            ),
          if (state.effectiveSystemGain != null)
            _StatusRow(
              label: 'Effective system gain',
              value: _gainLabel(state.effectiveSystemGain!),
            ),
          if (state.mixedSystemFramesBuffered != null)
            _StatusRow(
              label: 'System frames buffered',
              value: state.mixedSystemFramesBuffered.toString(),
            ),
          if (state.mixedMicFramesBuffered != null)
            _StatusRow(
              label: 'Mic frames buffered',
              value: state.mixedMicFramesBuffered.toString(),
            ),
          const SizedBox(height: AppSpacing.sm),
          _AudioLevelMeter(
            label: 'Mixed level',
            level: state.mixedAudioLevel,
            isSilent: state.isMixedSilent,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            state.versionHelperText,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusBanner(state: state),
          if (state.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              text: state.warnings.first,
            ),
          ],
          if (state.mixedWarnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.graphic_eq_outlined,
              color: AppColors.warning,
              text: state.mixedWarnings.first,
            ),
          ],
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.error_outline,
              color: AppColors.destructive,
              text: state.errorMessage!,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: state.canRunSystemPlayback
                  ? controller.runSystemPlaybackTest
                  : null,
              icon: const Icon(Icons.graphic_eq_outlined),
              label: const Text('Test system audio capture'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed:
                  state.canRunMicrophone ? controller.runMicrophoneTest : null,
              icon: const Icon(Icons.mic_outlined),
              label: const Text('Test microphone capture'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed:
                  state.canRunMixed ? controller.runMixedAudioTest : null,
              icon: const Icon(Icons.join_inner_outlined),
              label: const Text('Test mixed audio capture'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: state.canStop ? controller.stopSmokeTest : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop foreground service'),
            ),
          ),
          if (state.events.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Latest native event: ${_eventLabel(state.events.first)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final AndroidCaptureSmokeTestState state;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: _statusColor(state).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: _statusColor(state).withValues(alpha: 0.35)),
      ),
      child: Text(
        state.statusText,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textPrimary,
          height: 1.35,
        ),
      ),
    );
  }
}

class _AudioLevelMeter extends StatelessWidget {
  const _AudioLevelMeter({
    required this.label,
    required this.level,
    required this.isSilent,
  });

  final String label;
  final double level;
  final bool isSilent;

  @override
  Widget build(BuildContext context) {
    final normalizedLevel = level.clamp(0.0, 1.0).toDouble();
    final percent = (normalizedLevel * 100).round();
    final color = isSilent ? AppColors.warning : AppColors.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            Text(
              isSilent ? '$percent% · silent' : '$percent%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: normalizedLevel,
            minHeight: 8,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.icon,
    required this.color,
    required this.text,
  });

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, height: 1.35),
          ),
        ),
      ],
    );
  }
}

Color _statusColor(AndroidCaptureSmokeTestState state) {
  return switch (state.status) {
    AndroidCaptureSmokeTestStatus.serviceRunning ||
    AndroidCaptureSmokeTestStatus.playbackCaptureRunning => AppColors.success,
    AndroidCaptureSmokeTestStatus.serviceFailed ||
    AndroidCaptureSmokeTestStatus.projectionDenied ||
    AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10 ||
    AndroidCaptureSmokeTestStatus.nonAndroid => AppColors.destructive,
    AndroidCaptureSmokeTestStatus.serviceStarting ||
    AndroidCaptureSmokeTestStatus.playbackCaptureStarting ||
    AndroidCaptureSmokeTestStatus.requestingPermissions ||
    AndroidCaptureSmokeTestStatus.requestingProjection => AppColors.warning,
    _ => AppColors.cyan,
  };
}

String _eventLabel(LiveCaptureEvent event) {
  final status = event.status;
  if (status is String && status.isNotEmpty) {
    return status;
  }
  final code = event.code;
  if (code is String && code.isNotEmpty) {
    return code;
  }
  return event.type.toString();
}

String _effectLabel(bool? available, bool? enabled) {
  if (available == null && enabled == null) {
    return 'not checked';
  }
  final availability = available == true ? 'available' : 'unavailable';
  final enabledText = enabled == true ? 'enabled' : 'disabled';
  return '$availability · $enabledText';
}

String _gainLabel(double gain) {
  return gain.toStringAsFixed(2);
}
