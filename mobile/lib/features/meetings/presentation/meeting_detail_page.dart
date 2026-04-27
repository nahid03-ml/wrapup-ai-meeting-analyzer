import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';

class MeetingDetailPage extends StatelessWidget {
  const MeetingDetailPage({required this.meetingId, super.key});

  final String meetingId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meeting Detail')),
      body: _StubCard(
        child: EmptyState(
          icon: Icons.article_outlined,
          title: 'Meeting Detail',
          subtitle:
              'Meeting ID: $meetingId\nRead-only detail tabs arrive in Phase 4B',
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
