import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/env.dart';
import '../../../../core/languages/supported_languages.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/live_recording_controller_provider.dart';
import '../../application/live_recording_state.dart';

const _vercelBackendWarning =
    'Backend URL appears to be a Vercel frontend URL. Live transcription needs '
    'the FastAPI backend host that supports WebSocket.';

class LiveTranscriptionBetaPanel extends ConsumerStatefulWidget {
  const LiveTranscriptionBetaPanel({super.key});

  @override
  ConsumerState<LiveTranscriptionBetaPanel> createState() =>
      _LiveTranscriptionBetaPanelState();
}

class _LiveTranscriptionBetaPanelState
    extends ConsumerState<LiveTranscriptionBetaPanel> {
  late final TextEditingController _meetingNameController;
  String? _languageCode;
  bool _healthChecking = false;
  bool? _healthOk;
  String? _healthMessage;
  bool _showAdvancedDiagnostics = false;

  @override
  void initState() {
    super.initState();
    _meetingNameController = TextEditingController();
    _meetingNameController.addListener(_handleMeetingNameChanged);
  }

  @override
  void dispose() {
    _meetingNameController.removeListener(_handleMeetingNameChanged);
    _meetingNameController.dispose();
    super.dispose();
  }

  void _handleMeetingNameChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(liveRecordingControllerProvider);
    final controller = ref.read(liveRecordingControllerProvider.notifier);
    final diagnostics = _LiveBackendDiagnostics.fromBackendUrl(Env.backendUrl);
    final canEdit = state is LiveIdle || state is LiveFailed;
    final hasMeetingName = _meetingNameController.text.trim().isNotEmpty;
    final hasLanguage = _languageCode != null;
    final canStart = canEdit && hasMeetingName && hasLanguage;
    final showSetup = state is LiveIdle || state is LiveFailed;
    final userWarning = state.warnings.isEmpty
        ? null
        : _userFacingWarning(state.warnings.last);

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
          if (showSetup)
            _LiveCaptureSetupForm(
              meetingNameController: _meetingNameController,
              languageCode: _languageCode,
              canEdit: canEdit,
              canStart: canStart,
              onLanguageChanged: (value) {
                setState(() => _languageCode = value);
              },
              onStart: () {
                final languageCode = _languageCode;
                if (languageCode == null) {
                  return;
                }
                FocusScope.of(context).unfocus();
                controller.startAndroidMixedLive(
                  title: _meetingNameController.text,
                  languageCode: languageCode,
                );
              },
            )
          else
            _LiveCaptureStatusCard(
              state: state,
              meetingName: _displayMeetingName(_meetingNameController.text),
              languageName: _languageName(state.languageCode ?? _languageCode),
              onPause: state is LiveStreaming ? controller.pause : null,
              onResume: state is LivePaused ? controller.resume : null,
              onStop:
                  state is LiveStreaming ||
                      state is LiveStartingCapture ||
                      state is LivePaused ||
                      state is LiveResuming
                  ? controller.stop
                  : null,
              onOpenMeeting: state is LiveDone && state.meetingId != null
                  ? () => context.push(
                      AppRoutes.meetingDetail.replaceFirst(
                        ':id',
                        Uri.encodeComponent(state.meetingId!),
                      ),
                    )
                  : null,
            ),
          if (userWarning != null) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageBox(
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              text: userWarning,
            ),
          ],
          if (state is LiveFailed) ...[
            const SizedBox(height: AppSpacing.md),
            _MessageBox(
              icon: Icons.error_outline,
              color: AppColors.destructive,
              text: _userFacingError(state.errorMessage),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AdvancedDiagnosticsCard(
            state: state,
            diagnostics: diagnostics,
            expanded: _showAdvancedDiagnostics,
            healthChecking: _healthChecking,
            healthOk: _healthOk,
            healthMessage: _healthMessage,
            onExpansionChanged: (expanded) {
              setState(() => _showAdvancedDiagnostics = expanded);
            },
            onTestHealth: _healthChecking
                ? null
                : () => _testBackendHealth(diagnostics.healthUri),
          ),
        ],
      ),
    );
  }

  Future<void> _testBackendHealth(Uri healthUri) async {
    setState(() {
      _healthChecking = true;
      _healthOk = null;
      _healthMessage = null;
    });

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 8),
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
        headers: {'Accept': 'application/json'},
      ),
    );

    try {
      final response = await dio.getUri<dynamic>(healthUri);

      if (!mounted) return;
      final statusCode = response.statusCode;
      final ok = statusCode != null && statusCode >= 200 && statusCode < 300;
      setState(() {
        _healthChecking = false;
        _healthOk = ok;
        _healthMessage = ok
            ? 'HTTP health check passed.'
            : 'HTTP health check returned status ${statusCode ?? 'unknown'}.';
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _healthChecking = false;
        _healthOk = false;
        _healthMessage = _safeHealthFailureMessage(error);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _healthChecking = false;
        _healthOk = false;
        _healthMessage = 'HTTP health check failed.';
      });
    } finally {
      dio.close();
    }
  }
}

class _LiveCaptureSetupForm extends StatelessWidget {
  const _LiveCaptureSetupForm({
    required this.meetingNameController,
    required this.languageCode,
    required this.canEdit,
    required this.canStart,
    required this.onLanguageChanged,
    required this.onStart,
  });

  final TextEditingController meetingNameController;
  final String? languageCode;
  final bool canEdit;
  final bool canStart;
  final ValueChanged<String?> onLanguageChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: meetingNameController,
          enabled: canEdit,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Meeting name',
            hintText: 'Example: Weekly team meeting',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        DropdownButtonFormField<String>(
          initialValue: languageCode,
          isExpanded: true,
          hint: const Text('Select a language'),
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
          onChanged: canEdit ? onLanguageChanged : null,
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.privacy_tip_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Android may ask for microphone and system audio permission before capture starts.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: canStart ? onStart : null,
            icon: const Icon(Icons.play_arrow_outlined),
            label: const Text('Start meeting capture'),
          ),
        ),
      ],
    );
  }
}

class _LiveCaptureStatusCard extends StatelessWidget {
  const _LiveCaptureStatusCard({
    required this.state,
    required this.meetingName,
    required this.languageName,
    required this.onPause,
    required this.onResume,
    required this.onStop,
    required this.onOpenMeeting,
  });

  final LiveRecordingState state;
  final String meetingName;
  final String languageName;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onStop;
  final VoidCallback? onOpenMeeting;

  @override
  Widget build(BuildContext context) {
    final doneState = state is LiveDone ? state as LiveDone : null;
    final showMeter = state is! LiveDone && state is! LiveFailed;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StatusHeader(state: state),
          const SizedBox(height: AppSpacing.md),
          _InfoRow(label: 'Meeting name', value: meetingName),
          _InfoRow(label: 'Language', value: languageName),
          if (showMeter) ...[
            const SizedBox(height: AppSpacing.md),
            _AudioLevelMeter(state: state),
          ],
          const SizedBox(height: AppSpacing.md),
          _TranscriptPreview(state: state),
          if (doneState != null &&
              doneState.finalTranscript.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Final transcript preview',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _previewTranscript(doneState.finalTranscript),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (doneState != null && onOpenMeeting != null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onOpenMeeting,
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Open meeting'),
              ),
            )
          else ...[
            if (state is LivePaused)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: const Text('Resume'),
                ),
              )
            else if (state is LiveStreaming)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: onPause,
                  icon: const Icon(Icons.pause_outlined),
                  label: const Text('Pause'),
                ),
              ),
            if (state is LivePaused || state is LiveStreaming)
              const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: state is LiveStopping ? null : onStop,
                icon: const Icon(Icons.stop_circle_outlined),
                label: Text(
                  state is LiveStopping ? 'Stopping safely...' : 'Stop capture',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.state});

  final LiveRecordingState state;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(state);
    final icon = state is LiveDone
        ? Icons.check_circle_outline
        : state is LiveStopping
        ? Icons.hourglass_top_outlined
        : state is LivePaused
        ? Icons.pause_circle_outline
        : Icons.graphic_eq_outlined;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _statusTitle(state),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                _statusDescription(state),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AudioLevelMeter extends StatelessWidget {
  const _AudioLevelMeter({required this.state});

  final LiveRecordingState state;

  @override
  Widget build(BuildContext context) {
    final hasLevel = state.hasAudioLevel;
    final paused = state is LivePaused || state.isPaused;
    final level = paused
        ? 0.0
        : hasLevel
        ? state.audioLevel.clamp(0.0, 1.0).toDouble()
        : 0.0;
    final detected = !paused && hasLevel && state.isAudioDetected;
    final color = detected ? AppColors.success : AppColors.warning;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Audio level',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              paused
                  ? 'Audio not being transcribed'
                  : detected
                  ? 'Audio detected'
                  : 'No audio detected yet',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: detected ? AppColors.success : AppColors.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
          child: LinearProgressIndicator(
            value: level,
            minHeight: 10,
            backgroundColor: AppColors.border,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _TranscriptPreview extends StatelessWidget {
  const _TranscriptPreview({required this.state});

  final LiveRecordingState state;

  @override
  Widget build(BuildContext context) {
    final lines = state.transcriptLines.reversed.take(8).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          state is LiveDone ? 'Transcript saved' : 'Live transcript',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (lines.isEmpty)
          Text(
            state is LiveDone
                ? 'Transcript is ready.'
                : 'Transcript preview will appear here as the meeting is captured.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          )
        else
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                line.isFinal ? line.text : '${line.text}...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: line.isFinal
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                  fontStyle: line.isFinal ? FontStyle.normal : FontStyle.italic,
                  height: 1.35,
                ),
              ),
            ),
      ],
    );
  }
}

class _AdvancedDiagnosticsCard extends StatelessWidget {
  const _AdvancedDiagnosticsCard({
    required this.state,
    required this.diagnostics,
    required this.expanded,
    required this.healthChecking,
    required this.healthOk,
    required this.healthMessage,
    required this.onExpansionChanged,
    required this.onTestHealth,
  });

  final LiveRecordingState state;
  final _LiveBackendDiagnostics diagnostics;
  final bool expanded;
  final bool healthChecking;
  final bool? healthOk;
  final String? healthMessage;
  final ValueChanged<bool> onExpansionChanged;
  final VoidCallback? onTestHealth;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expanded,
          onExpansionChanged: onExpansionChanged,
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          leading: const Icon(
            Icons.settings_outlined,
            color: AppColors.textSecondary,
          ),
          title: Text(
            'Advanced diagnostics',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          children: [
            if (expanded) ...[
              _StatusRow(label: 'Backend host', value: diagnostics.host),
              _StatusRow(
                label: 'Backend scheme',
                value: diagnostics.backendScheme,
              ),
              _StatusRow(
                label: 'WebSocket scheme',
                value: diagnostics.webSocketScheme,
              ),
              _StatusRow(
                label: 'WebSocket status',
                value: state.webSocketStatus,
              ),
              _StatusRow(label: 'Capture status', value: state.captureStatus),
              _StatusRow(label: 'Paused', value: state.isPaused ? 'yes' : 'no'),
              _StatusRow(
                label: 'PCM chunks sent',
                value: '${state.pcmChunksSent}',
              ),
              _StatusRow(
                label: 'PCM chunks dropped',
                value: '${state.pcmChunksDropped}',
              ),
              _StatusRow(
                label: 'PCM chunks skipped while paused',
                value: '${state.pcmChunksSkippedWhilePaused}',
              ),
              _StatusRow(
                label: 'Last PCM chunk bytes',
                value: '${state.lastPcmChunkBytes}',
              ),
              if (diagnostics.isLikelyVercelFrontend) ...[
                const SizedBox(height: AppSpacing.sm),
                const _MessageBox(
                  icon: Icons.warning_amber_outlined,
                  color: AppColors.warning,
                  text: _vercelBackendWarning,
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Text(
                'HTTP health only. This does not test WebSocket streaming.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onTestHealth,
                  icon: healthChecking
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.health_and_safety_outlined),
                  label: Text(
                    healthChecking
                        ? 'Testing backend health...'
                        : 'Test backend health',
                  ),
                ),
              ),
              if (healthMessage != null) ...[
                const SizedBox(height: AppSpacing.sm),
                _MessageBox(
                  icon: healthOk == true
                      ? Icons.check_circle_outline
                      : Icons.error_outline,
                  color: healthOk == true
                      ? AppColors.success
                      : AppColors.destructive,
                  text: healthMessage!,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
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

class _LiveBackendDiagnostics {
  const _LiveBackendDiagnostics({
    required this.backendScheme,
    required this.host,
    required this.webSocketScheme,
    required this.healthUri,
    required this.isLikelyVercelFrontend,
  });

  final String backendScheme;
  final String host;
  final String webSocketScheme;
  final Uri healthUri;
  final bool isLikelyVercelFrontend;

  factory _LiveBackendDiagnostics.fromBackendUrl(String backendUrl) {
    final uri = Uri.parse(backendUrl.trim());
    final backendScheme = uri.scheme.isEmpty ? 'unknown' : uri.scheme;
    final host = uri.host.isEmpty ? 'unknown' : uri.host;
    final webSocketScheme = _webSocketSchemeFor(backendScheme);
    return _LiveBackendDiagnostics(
      backendScheme: backendScheme,
      host: host,
      webSocketScheme: webSocketScheme,
      healthUri: _healthUriFor(uri),
      isLikelyVercelFrontend:
          host.toLowerCase().endsWith('.vercel.app') ||
          host.toLowerCase() == 'vercel.app',
    );
  }
}

String _displayMeetingName(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? 'Live meeting' : trimmed;
}

String _languageName(String? languageCode) {
  if (languageCode == null) {
    return 'Not selected';
  }
  for (final language in supportedLanguages) {
    if (language.code == languageCode) {
      return language.name;
    }
  }
  return languageCode;
}

String _statusTitle(LiveRecordingState state) {
  if (state is LiveDone) return 'Transcript saved';
  if (state is LiveStopping) return 'Stopping safely...';
  if (state is LiveResuming) return 'Resuming meeting capture...';
  if (state is LivePaused) return 'Meeting capture paused.';
  if (state is LiveStreaming) return 'Listening to meeting audio...';
  if (state is LiveFailed) return 'Capture stopped';
  return 'Preparing capture...';
}

String _statusDescription(LiveRecordingState state) {
  if (state is LiveDone) return 'Transcript is ready.';
  if (state is LiveStopping) return 'Preparing your transcript...';
  if (state is LiveResuming) return 'Live transcript will continue here.';
  if (state is LivePaused) {
    return 'Audio is not being transcribed while paused.';
  }
  if (state is LiveStreaming) return 'Live transcript is being created...';
  if (state is LiveStartingCapture) {
    return 'Android may ask for microphone and system audio permission before capture starts.';
  }
  if (state is LiveFailed) return 'Please try again.';
  return 'Getting meeting capture ready...';
}

Color _statusColor(LiveRecordingState state) {
  if (state is LiveDone || state is LiveStreaming) return AppColors.success;
  if (state is LiveFailed) return AppColors.destructive;
  if (state is LivePaused) return AppColors.cyan;
  if (state is LiveCreatingSession ||
      state is LiveConnecting ||
      state is LiveReadyNoCapture ||
      state is LiveStartingCapture ||
      state is LiveResuming ||
      state is LiveStopping) {
    return AppColors.warning;
  }
  return AppColors.cyan;
}

String _previewTranscript(String transcript) {
  final trimmed = transcript.trim();
  if (trimmed.length <= 1200) {
    return trimmed;
  }
  return '${trimmed.substring(0, 1200)}...';
}

String? _userFacingWarning(String warning) {
  final lower = warning.toLowerCase();
  if (lower.contains('background')) {
    return 'Live capture continued in the background.';
  }
  if (lower.contains('finalizing') || lower.contains('final processing')) {
    return 'Transcript is still being prepared. You can open the meeting shortly.';
  }
  if (lower.contains('permission') || lower.contains('projection')) {
    return 'Android needs permission before capture can start.';
  }
  return null;
}

String _userFacingError(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('meeting title') || lower.contains('meeting name')) {
    return 'Meeting name is required.';
  }
  if (lower.contains('lost connection')) {
    return 'Meeting capture lost connection. Please start again.';
  }
  if (lower.contains('microphone')) {
    return 'Microphone permission is required to capture your voice.';
  }
  if (lower.contains('mediaprojection') ||
      lower.contains('projection') ||
      lower.contains('system audio')) {
    return 'System audio permission is required to capture meeting audio.';
  }
  if (lower.contains('backend') ||
      lower.contains('websocket') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('timed out') ||
      lower.contains('network')) {
    return 'Could not start meeting capture. Please check your internet connection and try again.';
  }
  if (lower.contains('stopped unexpectedly') ||
      lower.contains('android live capture failed') ||
      lower.contains('capture failed')) {
    return 'Capture stopped unexpectedly. Please try again.';
  }
  if (lower.contains('sign in') || lower.contains('authentication')) {
    return 'Please sign in again to start meeting capture.';
  }
  return 'Could not start meeting capture. Please try again.';
}

String _webSocketSchemeFor(String backendScheme) {
  return switch (backendScheme.toLowerCase()) {
    'http' => 'ws',
    'https' => 'wss',
    'ws' => 'ws',
    'wss' => 'wss',
    _ => 'unknown',
  };
}

Uri _healthUriFor(Uri backendUri) {
  final basePathSegments = backendUri.pathSegments
      .where((segment) => segment.trim().isNotEmpty)
      .toList(growable: false);

  return Uri(
    scheme: backendUri.scheme,
    host: backendUri.host,
    port: backendUri.hasPort ? backendUri.port : null,
    pathSegments: <String>[...basePathSegments, 'healthz'],
  );
}

String _safeHealthFailureMessage(DioException error) {
  final statusCode = error.response?.statusCode;
  if (statusCode != null) {
    return 'HTTP health check returned status $statusCode.';
  }

  return switch (error.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout => 'HTTP health check timed out.',
    DioExceptionType.connectionError => 'HTTP health check could not connect.',
    DioExceptionType.badCertificate =>
      'HTTP health check failed TLS validation.',
    _ => 'HTTP health check failed.',
  };
}
