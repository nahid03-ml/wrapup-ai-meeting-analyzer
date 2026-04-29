import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../data/capture_mode.dart';
import 'widgets/android_capture_smoke_test_panel.dart';
import 'widgets/capture_mode_card.dart';
import 'widgets/live_transcription_beta_panel.dart';

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
              'Android live capture',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'WrapUp uses Android OS-level capture permission for device audio and microphone mixing. Some meeting apps may block device audio, so run the proof checks before the beta stream.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const CaptureModeCard(mode: androidLiveCaptureMode),
            const SizedBox(height: AppSpacing.md),
            const LiveTranscriptionBetaPanel(),
            const SizedBox(height: AppSpacing.md),
            const AndroidCaptureSmokeTestPanel(),
          ],
        ),
      ),
    );
  }
}
