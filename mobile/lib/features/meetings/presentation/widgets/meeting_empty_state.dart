import 'package:flutter/material.dart';

import '../../../../core/widgets/empty_state.dart';

class MeetingEmptyState extends StatelessWidget {
  const MeetingEmptyState({
    this.title = 'No meetings yet',
    this.subtitle = 'Upload a recording or start an instant meeting to begin.',
    this.onAction,
    this.actionLabel,
    super.key,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onAction;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.mic_none,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction,
    );
  }
}
