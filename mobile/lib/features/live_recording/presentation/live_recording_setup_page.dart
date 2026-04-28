import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/capture_mode.dart';
import 'widgets/android_capture_smoke_test_panel.dart';
import 'widgets/capture_mode_card.dart';

class LiveRecordingSetupPage extends StatelessWidget {
  const LiveRecordingSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Live capture')),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Text(
              'Choose recording source',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'WrapUp does not rely on Zoom, Meet, or Teams APIs. It captures audio through supported OS-level capture paths.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final mode in liveCaptureModes) ...[
              CaptureModeCard(mode: mode),
              if (mode.id == CaptureModeId.androidDeviceAudioMicBeta) ...[
                const SizedBox(height: AppSpacing.md),
                const AndroidCaptureSmokeTestPanel(),
              ],
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
