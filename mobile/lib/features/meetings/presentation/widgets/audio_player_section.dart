import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../application/meeting_detail_provider.dart';
import '../../data/session.dart';

class AudioPlayerSection extends ConsumerStatefulWidget {
  const AudioPlayerSection({required this.session, super.key});

  final MeetingSession session;

  @override
  ConsumerState<AudioPlayerSection> createState() => _AudioPlayerSectionState();
}

class _AudioPlayerSectionState extends ConsumerState<AudioPlayerSection> {
  static const _speedOptions = <double>[0.75, 1, 1.25, 1.5, 2];
  static const _loadTimeout = Duration(seconds: 20);

  late final AudioPlayer _player;
  late final StreamSubscription<PlaybackEvent> _playbackEventSubscription;
  String? _loadedUrl;
  String? _loadingUrl;
  _AudioLoadFailure? _loadError;
  double _speed = 1;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _playbackEventSubscription = _player.playbackEventStream.listen(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        _debugAudioLog(
          'playback stream error session=${widget.session.id} '
          'error=${_safeError(error)}',
        );
        if (!mounted) return;
        setState(() {
          _loadedUrl = null;
          _loadingUrl = null;
          _loadError = _AudioLoadFailure.fromError(error);
        });
      },
    );
  }

  @override
  void dispose() {
    _playbackEventSubscription.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final audioRef = widget.session.audioFileUrl?.trim();
    if (audioRef == null || audioRef.isEmpty) {
      return const SizedBox.shrink();
    }

    final playableUrlValue = ref.watch(
      audioPlayableUrlProvider(widget.session),
    );

    return playableUrlValue.when(
      data: (playableUrl) {
        final url = playableUrl?.trim();
        if (url == null || url.isEmpty) {
          return const SizedBox.shrink();
        }
        _scheduleLoad(url);
        return _PlayerCard(
          player: _player,
          speed: _speed,
          loadError: _loadError,
          isLoadingUrl: _loadingUrl == url,
          onRetry: () => _loadUrl(url, force: true),
          onSeekRelative: _seekRelative,
          onSpeedChanged: _setSpeed,
        );
      },
      loading: () =>
          const _AudioShell(child: LinearProgressIndicator(minHeight: 2)),
      error: (error, stackTrace) => _AudioError(
        message: 'Audio URL could not be created. Check storage access.',
        onRetry: () => ref.invalidate(audioPlayableUrlProvider(widget.session)),
      ),
    );
  }

  void _scheduleLoad(String url) {
    if (url == _loadedUrl || url == _loadingUrl) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadUrl(url);
      }
    });
  }

  Future<void> _loadUrl(String url, {bool force = false}) async {
    if (!force && (url == _loadedUrl || url == _loadingUrl)) return;
    setState(() {
      _loadingUrl = url;
      _loadError = null;
      if (force) {
        _loadedUrl = null;
      }
    });

    try {
      _debugAudioLog(
        'loading audio session=${widget.session.id} urlLength=${url.length}',
      );
      await _player.stop();
      await _player.setUrl(url).timeout(_loadTimeout);
      await _player.setSpeed(_speed);
      if (!mounted) return;
      setState(() {
        _loadedUrl = url;
        _loadingUrl = null;
      });
      _debugAudioLog('audio ready session=${widget.session.id}');
    } on TimeoutException catch (error) {
      _debugAudioLog('audio load timeout session=${widget.session.id}');
      if (!mounted) return;
      setState(() {
        _loadedUrl = null;
        _loadingUrl = null;
        _loadError = _AudioLoadFailure.timeout(error);
      });
    } catch (error) {
      _debugAudioLog(
        'audio load failed session=${widget.session.id} '
        'error=${_safeError(error)}',
      );
      if (!mounted) return;
      setState(() {
        _loadedUrl = null;
        _loadingUrl = null;
        _loadError = _AudioLoadFailure.fromError(error);
      });
    }
  }

  Future<void> _seekRelative(Duration offset) async {
    final duration = _player.duration;
    final current = _player.position;
    var next = current + offset;
    if (next < Duration.zero) {
      next = Duration.zero;
    }
    if (duration != null && next > duration) {
      next = duration;
    }
    await _player.seek(next);
  }

  Future<void> _setSpeed(double speed) async {
    setState(() {
      _speed = speed;
    });
    await _player.setSpeed(speed);
  }
}

class _PlayerCard extends StatelessWidget {
  const _PlayerCard({
    required this.player,
    required this.speed,
    required this.loadError,
    required this.isLoadingUrl,
    required this.onRetry,
    required this.onSeekRelative,
    required this.onSpeedChanged,
  });

  final AudioPlayer player;
  final double speed;
  final _AudioLoadFailure? loadError;
  final bool isLoadingUrl;
  final VoidCallback onRetry;
  final ValueChanged<Duration> onSeekRelative;
  final ValueChanged<double> onSpeedChanged;

  @override
  Widget build(BuildContext context) {
    if (loadError != null) {
      return _AudioError(message: loadError!.message, onRetry: onRetry);
    }

    return _AudioShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _PlayPauseButton(player: player, isLoadingUrl: isLoadingUrl),
              const SizedBox(width: AppSpacing.md),
              Expanded(child: _PositionSlider(player: player)),
              const SizedBox(width: AppSpacing.sm),
              _SpeedMenu(speed: speed, onChanged: onSpeedChanged),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _SkipButton(
                icon: Icons.replay,
                label: 'Back 15 seconds',
                onPressed: () => onSeekRelative(const Duration(seconds: -15)),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SkipButton(
                icon: Icons.forward,
                label: 'Forward 15 seconds',
                onPressed: () => onSeekRelative(const Duration(seconds: 15)),
              ),
              const Spacer(),
              StreamBuilder<PlayerState>(
                stream: player.playerStateStream,
                initialData: player.playerState,
                builder: (context, snapshot) {
                  final processingState =
                      snapshot.data?.processingState ?? ProcessingState.loading;
                  final isBusy =
                      isLoadingUrl ||
                      processingState == ProcessingState.loading ||
                      processingState == ProcessingState.buffering;
                  if (!isBusy) return const SizedBox.shrink();
                  return const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AudioLoadFailure {
  const _AudioLoadFailure(this.message);

  factory _AudioLoadFailure.timeout(TimeoutException _) {
    return const _AudioLoadFailure(
      'Audio is taking too long to load. Try again.',
    );
  }

  factory _AudioLoadFailure.fromError(Object error) {
    final text = error.toString().toLowerCase();
    if (text.contains('source') ||
        text.contains('decoder') ||
        text.contains('format') ||
        text.contains('exoplayer')) {
      return const _AudioLoadFailure(
        'This file may use an unsupported audio codec. Try MP3, M4A, or WAV.',
      );
    }
    return const _AudioLoadFailure(
      'Audio could not be loaded. Check storage access or file format.',
    );
  }

  final String message;
}

class _AudioShell extends StatelessWidget {
  const _AudioShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                ),
                child: const Icon(
                  Icons.graphic_eq,
                  color: AppColors.cyan,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Meeting Audio',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({required this.player, required this.isLoadingUrl});

  final AudioPlayer player;
  final bool isLoadingUrl;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      initialData: player.playerState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        final processingState = state?.processingState;
        final isBusy =
            isLoadingUrl ||
            processingState == ProcessingState.loading ||
            processingState == ProcessingState.buffering;
        final isCompleted = processingState == ProcessingState.completed;
        final isPlaying = state?.playing == true && !isCompleted;

        return FilledButton(
          onPressed: isBusy
              ? null
              : () async {
                  if (isCompleted) {
                    await player.seek(Duration.zero);
                    await player.play();
                  } else if (isPlaying) {
                    await player.pause();
                  } else {
                    await player.play();
                  }
                },
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: Icon(
            isCompleted
                ? Icons.replay
                : isPlaying
                ? Icons.pause
                : Icons.play_arrow,
          ),
        );
      },
    );
  }
}

class _PositionSlider extends StatelessWidget {
  const _PositionSlider({required this.player});

  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: player.durationStream,
      initialData: player.duration,
      builder: (context, durationSnapshot) {
        final duration = durationSnapshot.data ?? Duration.zero;

        return StreamBuilder<Duration>(
          stream: player.positionStream,
          initialData: player.position,
          builder: (context, positionSnapshot) {
            final rawPosition = positionSnapshot.data ?? Duration.zero;
            final position = _clampPosition(rawPosition, duration);
            final hasDuration = duration > Duration.zero;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(
                      enabledThumbRadius: 6,
                    ),
                  ),
                  child: Slider(
                    value: hasDuration ? position.inMilliseconds.toDouble() : 0,
                    max: hasDuration ? duration.inMilliseconds.toDouble() : 1,
                    onChanged: hasDuration
                        ? (value) {
                            player.seek(Duration(milliseconds: value.round()));
                          }
                        : null,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      _formatDuration(position),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      hasDuration ? _formatDuration(duration) : '--:--',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _SpeedMenu extends StatelessWidget {
  const _SpeedMenu({required this.speed, required this.onChanged});

  final double speed;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<double>(
      tooltip: 'Playback speed',
      initialValue: speed,
      onSelected: onChanged,
      itemBuilder: (context) => _AudioPlayerSectionState._speedOptions
          .map(
            (speed) => PopupMenuItem<double>(
              value: speed,
              child: Text(_formatSpeed(speed)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
          border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _formatSpeed(speed),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Icon(Icons.expand_more, size: 14, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _AudioError extends StatelessWidget {
  const _AudioError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _AudioShell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: AppColors.destructive),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

Duration _clampPosition(Duration position, Duration duration) {
  if (position < Duration.zero) return Duration.zero;
  if (duration > Duration.zero && position > duration) return duration;
  return position;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (hours > 0) {
    return '$hours:$minutes:$seconds';
  }
  return '$minutes:$seconds';
}

String _formatSpeed(double speed) {
  if (speed == speed.roundToDouble()) {
    return '${speed.toInt()}x';
  }
  return '${speed}x';
}

String _safeError(Object error) {
  return error.toString().replaceAll(RegExp(r'https?://\S+'), '[url]');
}

void _debugAudioLog(String message) {
  if (!kDebugMode) return;
  developer.log(message, name: 'WrapUpAudio');
}
