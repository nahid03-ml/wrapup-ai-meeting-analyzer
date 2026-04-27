import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';

class ActionItemsPage extends StatelessWidget {
  const ActionItemsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: const _StubCard(
        child: EmptyState(
          icon: Icons.task_alt_outlined,
          title: 'Tasks',
          subtitle: 'Action items arrive in Phase 4C',
        ),
      ),
    );
  }
}

class _StubCard extends StatelessWidget {
  const _StubCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
