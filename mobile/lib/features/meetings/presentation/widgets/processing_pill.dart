import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ProcessingPill extends StatefulWidget {
  const ProcessingPill({
    required this.isProcessing,
    this.progress,
    this.message,
    super.key,
  });

  final bool isProcessing;
  final int? progress;
  final String? message;

  @override
  State<ProcessingPill> createState() => _ProcessingPillState();
}

class _ProcessingPillState extends State<ProcessingPill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(
      begin: 0.75,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _opacity = Tween<double>(
      begin: 0.45,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.isProcessing) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ProcessingPill oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isProcessing == widget.isProcessing) return;
    if (widget.isProcessing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isProcessing) return const SizedBox.shrink();

    final progress = widget.progress?.clamp(0, 100);
    final rawMessage = widget.message?.trim();
    final label = rawMessage == null || rawMessage.isEmpty
        ? 'Processing'
        : rawMessage;
    final visibleText = progress == null ? label : '$label $progress%';
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.warning,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _opacity,
            child: ScaleTransition(
              scale: _scale,
              child: Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            visibleText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
