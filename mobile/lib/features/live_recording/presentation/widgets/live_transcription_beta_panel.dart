import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/languages/supported_languages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/live_recording_controller_provider.dart';
import '../../application/live_recording_state.dart';

class LiveTranscriptionBetaPanel extends ConsumerStatefulWidget {
  const LiveTranscriptionBetaPanel({super.key});

  @override
  ConsumerState<LiveTranscriptionBetaPanel> createState() =>
      _LiveTranscriptionBetaPanelState();
}

class _LiveTranscriptionBetaPanelState
    extends ConsumerState<LiveTranscriptionBetaPanel> {
  late final TextEditingController _titleController;
  late String _languageCode;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Live meeting');
    _languageCode = defaultSupportedLanguageCode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveRecordingControllerProvider);
    final controller = ref.read(liveRecordingControllerProvider.notifier);
    final isBusy = state is LiveCreatingSession ||
        state is LiveConnecting ||
        state is LiveStartingCapture ||
        state is LiveStreaming ||
        state is LiveStopping;
    final canStart = !isBusy || state is LiveDone || state is LiveFailed;
    final canStop = state is LiveStreaming || state is LiveStartingCapture;

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
              const Icon(Icons.closed_caption_outlined, color: AppColors.cyan),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Live transcription beta',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Streams the verified mixed Android audio to the backend for live transcription. Use this only after the system, mic, and mixed proof tests pass.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            enabled: canStart,
            decoration: const InputDecoration(
              labelText: 'Meeting title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _languageCode,
            decoration: const InputDecoration(
              labelText: 'Language',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final language in supportedLanguages)
                DropdownMenuItem(
                  value: language.code,
                  child: Text(language.name),
                ),
            ],
            onChanged: canStart
                ? (value) {
                    if (value != null) {
                      setState(() => _languageCode = value);
                    }
                  }
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          _StatusRow(label: 'Live session', value: _sessionStatus(state)),
          _StatusRow(label: 'WebSocket', value: state.webSocketStatus),
          _StatusRow(label: 'Capture', value: state.captureStatus),
          _StatusRow(label: 'PCM chunks sent', value: '${state.pcmChunksSent}'),
          _StatusRow(
            label: 'PCM chunks dropped',
            value: '${state.pcmChunksDropped}',
          ),
          _StatusRow(
            label: 'Last PCM chunk',
            value: '${state.lastPcmChunkBytes} bytes',
          ),
          if (state.meetingId != null)
            _StatusRow(label: 'Meeting ID', value: state.meetingId!),
          if (state.sessionId != null)
            _StatusRow(label: 'Session ID', value: state.sessionId!),
          const SizedBox(height: AppSpacing.sm),
          _StatusBanner(state: state),
          if (state.warnings.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              text: state.warnings.last,
            ),
          ],
          if (state is LiveFailed) ...[
            const SizedBox(height: AppSpacing.sm),
            _MessageBox(
              icon: Icons.error_outline,
              color: AppColors.destructive,
              text: state.errorMessage,
            ),
          ],
          if (state.transcriptLines.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Latest transcript',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final line in state.transcriptLines.reversed.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  line.isFinal ? line.text : '${line.text}...',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: line.isFinal
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
          ],
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canStart
                  ? () => controller.startAndroidMixedLive(
                        title: _titleController.text,
                        languageCode: _languageCode,
                      )
                  : null,
              icon: const Icon(Icons.play_arrow_outlined),
              label: const Text('Start live transcription'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canStop ? controller.stop : null,
              icon: const Icon(Icons.stop_circle_outlined),
              label: const Text('Stop live transcription'),
            ),
          ),
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

  final LiveRecordingState state;

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
        _statusText(state),
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
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: color,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

String _sessionStatus(LiveRecordingState state) {
  if (state is LiveIdle) return 'idle';
  if (state is LiveCreatingSession) return 'creating session';
  if (state is LiveConnecting) return 'connecting websocket';
  if (state is LiveStartingCapture) return 'starting capture';
  if (state is LiveStreaming) return 'streaming';
  if (state is LiveStopping) return 'stopping';
  if (state is LiveDone) return 'done';
  if (state is LiveFailed) return 'failed';
  return 'unknown';
}

String _statusText(LiveRecordingState state) {
  if (state is LiveIdle) return 'Ready to start a live transcription beta session.';
  if (state is LiveCreatingSession) return 'Creating live meeting and session rows.';
  if (state is LiveConnecting) return 'Opening live transcription WebSocket.';
  if (state is LiveStartingCapture) return 'Starting Android mixed capture.';
  if (state is LiveStreaming) return 'Streaming mixed PCM to live transcription.';
  if (state is LiveStopping) return 'Stopping capture and waiting for backend done.';
  if (state is LiveDone) {
    return state.finalTranscript.isEmpty
        ? 'Live transcription stopped. Final processing may still be completing.'
        : 'Live transcription done.';
  }
  if (state is LiveFailed) return 'Live transcription failed.';
  return 'Live transcription status updated.';
}

Color _statusColor(LiveRecordingState state) {
  if (state is LiveStreaming || state is LiveDone) return AppColors.success;
  if (state is LiveFailed) return AppColors.destructive;
  if (state is LiveCreatingSession ||
      state is LiveConnecting ||
      state is LiveStartingCapture ||
      state is LiveStopping) {
    return AppColors.warning;
  }
  return AppColors.cyan;
}
