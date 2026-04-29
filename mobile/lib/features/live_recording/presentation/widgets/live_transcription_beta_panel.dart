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

const _liveWebSocketPathTemplate = '/ws/live-transcription/{session_id}';
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
  late final TextEditingController _titleController;
  late String _languageCode;
  bool _healthChecking = false;
  bool? _healthOk;
  String? _healthMessage;
  bool _showBackendDiagnosticDetails = false;

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
    final isBusy =
        state is LiveCreatingSession ||
        state is LiveConnecting ||
        state is LiveStartingCapture ||
        state is LiveStreaming ||
        state is LiveStopping;
    final canStart = !isBusy || state is LiveDone || state is LiveFailed;
    final canStop = state is LiveStreaming || state is LiveStartingCapture;
    final diagnostics = _LiveBackendDiagnostics.fromBackendUrl(Env.backendUrl);

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
          _BackendDiagnosticsCard(
            diagnostics: diagnostics,
            healthChecking: _healthChecking,
            healthOk: _healthOk,
            healthMessage: _healthMessage,
            showDetails: _showBackendDiagnosticDetails,
            onToggleDetails: () {
              setState(
                () => _showBackendDiagnosticDetails =
                    !_showBackendDiagnosticDetails,
              );
            },
            onTestHealth: _healthChecking
                ? null
                : () => _testBackendHealth(diagnostics.healthUri),
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
            for (final line in state.transcriptLines.reversed.take(8))
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
          if (state is LiveDone && state.finalTranscript.trim().isNotEmpty) ...[
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
              _previewTranscript(state.finalTranscript),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                height: 1.35,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (state is LiveDone && state.meetingId != null) ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => context.push(
                  AppRoutes.meetingDetail.replaceFirst(
                    ':id',
                    Uri.encodeComponent(state.meetingId!),
                  ),
                ),
                icon: const Icon(Icons.open_in_new_outlined),
                label: const Text('Open meeting'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
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

class _BackendDiagnosticsCard extends StatelessWidget {
  const _BackendDiagnosticsCard({
    required this.diagnostics,
    required this.healthChecking,
    required this.healthOk,
    required this.healthMessage,
    required this.showDetails,
    required this.onToggleDetails,
    required this.onTestHealth,
  });

  final _LiveBackendDiagnostics diagnostics;
  final bool healthChecking;
  final bool? healthOk;
  final String? healthMessage;
  final bool showDetails;
  final VoidCallback onToggleDetails;
  final VoidCallback? onTestHealth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.background.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Backend diagnostics',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              IconButton(
                onPressed: onToggleDetails,
                tooltip: showDetails
                    ? 'Hide backend details'
                    : 'Show backend details',
                icon: Icon(
                  showDetails
                      ? Icons.expand_less_outlined
                      : Icons.expand_more_outlined,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          _StatusRow(label: 'Backend host', value: diagnostics.host),
          _StatusRow(label: 'Backend scheme', value: diagnostics.backendScheme),
          _StatusRow(
            label: 'WebSocket scheme',
            value: diagnostics.webSocketScheme,
          ),
          if (diagnostics.isLikelyVercelFrontend) ...[
            const SizedBox(height: AppSpacing.xs),
            const _MessageBox(
              icon: Icons.warning_amber_outlined,
              color: AppColors.warning,
              text: _vercelBackendWarning,
            ),
          ],
          if (showDetails) ...[
            const SizedBox(height: AppSpacing.xs),
            const _StatusRow(
              label: 'WebSocket path',
              value: _liveWebSocketPathTemplate,
            ),
            _StatusRow(
              label: 'Sanitized WebSocket target',
              value: diagnostics.sanitizedWebSocketTarget,
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
      ),
    );
  }
}

String _previewTranscript(String transcript) {
  final trimmed = transcript.trim();
  if (trimmed.length <= 1200) {
    return trimmed;
  }
  return '${trimmed.substring(0, 1200)}...';
}

class _LiveBackendDiagnostics {
  const _LiveBackendDiagnostics({
    required this.backendScheme,
    required this.host,
    required this.webSocketScheme,
    required this.sanitizedWebSocketTarget,
    required this.healthUri,
    required this.isLikelyVercelFrontend,
  });

  final String backendScheme;
  final String host;
  final String webSocketScheme;
  final String sanitizedWebSocketTarget;
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
      sanitizedWebSocketTarget:
          '$webSocketScheme://$host$_liveWebSocketPathTemplate',
      healthUri: _healthUriFor(uri),
      isLikelyVercelFrontend:
          host.toLowerCase().endsWith('.vercel.app') ||
          host.toLowerCase() == 'vercel.app',
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: color, height: 1.35),
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
  if (state is LiveIdle) {
    return 'Ready to start a live transcription beta session.';
  }
  if (state is LiveCreatingSession) {
    return 'Creating live meeting and session rows.';
  }
  if (state is LiveConnecting) return 'Opening live transcription WebSocket.';
  if (state is LiveStartingCapture) return 'Starting Android mixed capture.';
  if (state is LiveStreaming) {
    return 'Streaming mixed PCM to live transcription.';
  }
  if (state is LiveStopping) {
    return 'Stopping capture and waiting for backend done.';
  }
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
