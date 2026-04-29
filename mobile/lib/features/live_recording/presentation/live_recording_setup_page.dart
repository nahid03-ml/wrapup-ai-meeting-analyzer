import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'widgets/android_capture_smoke_test_panel.dart';
import 'widgets/live_transcription_beta_panel.dart';

class LiveRecordingSetupPage extends StatefulWidget {
  const LiveRecordingSetupPage({super.key});

  @override
  State<LiveRecordingSetupPage> createState() => _LiveRecordingSetupPageState();
}

class _LiveRecordingSetupPageState extends State<LiveRecordingSetupPage> {
  bool _showDeveloperTests = false;

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
              'Live meeting capture',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Capture meeting audio and create a live transcript.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const LiveTranscriptionBetaPanel(),
            const SizedBox(height: AppSpacing.md),
            _DeveloperCaptureTestsSection(
              expanded: _showDeveloperTests,
              onExpansionChanged: (expanded) {
                setState(() => _showDeveloperTests = expanded);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DeveloperCaptureTestsSection extends StatelessWidget {
  const _DeveloperCaptureTestsSection({
    required this.expanded,
    required this.onExpansionChanged,
  });

  final bool expanded;
  final ValueChanged<bool> onExpansionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          leading: const Icon(Icons.tune_outlined, color: AppColors.cyan),
          title: Text(
            'Developer capture tests',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            'Android proof tools from earlier phases.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          children: [if (expanded) const AndroidCaptureSmokeTestPanel()],
        ),
      ),
    );
  }
}
