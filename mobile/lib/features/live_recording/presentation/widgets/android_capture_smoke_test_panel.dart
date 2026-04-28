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
            'This only tests permission and foreground service startup. It does not record audio yet.',
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
          if (state.errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.error_outline,
              color: AppColors.destructive,
              text: state.errorMessage!,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: state.canRun ? controller.runSmokeTest : null,
                  icon: const Icon(Icons.verified_user_outlined),
                  label: const Text('Test Android capture permission'),
                ),
              ),
            ],
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
    AndroidCaptureSmokeTestStatus.serviceRunning => AppColors.success,
    AndroidCaptureSmokeTestStatus.serviceFailed ||
    AndroidCaptureSmokeTestStatus.projectionDenied ||
    AndroidCaptureSmokeTestStatus.unsupportedBelowAndroid10 ||
    AndroidCaptureSmokeTestStatus.nonAndroid => AppColors.destructive,
    AndroidCaptureSmokeTestStatus.serviceStarting ||
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
