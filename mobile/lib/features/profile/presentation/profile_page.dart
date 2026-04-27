import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const _StubCard(
        child: EmptyState(
          icon: Icons.person_outline,
          title: 'Profile',
          subtitle: 'Profile page arrives in Phase 4C',
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
