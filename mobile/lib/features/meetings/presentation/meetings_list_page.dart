import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';

class MeetingsListPage extends StatelessWidget {
  const MeetingsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meetings')),
      body: const _StubCard(
        child: EmptyState(
          icon: Icons.description_outlined,
          title: 'Meetings',
          subtitle: 'Meetings list arrives in Phase 4B',
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
