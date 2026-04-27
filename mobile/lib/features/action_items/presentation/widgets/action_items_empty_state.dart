import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state.dart';

class ActionItemsEmptyState extends StatelessWidget {
  const ActionItemsEmptyState({
    this.title = 'No action items yet',
    this.subtitle = 'Action items generated from meetings will appear here.',
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: EmptyState(
          icon: Icons.task_alt_outlined,
          title: title,
          subtitle: subtitle,
        ),
      ),
    );
  }
}
