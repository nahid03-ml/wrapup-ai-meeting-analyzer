import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/supabase_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../profile/application/profile_provider.dart';

/// Placeholder authenticated home. Real dashboard ships in Phase 5.
/// Now reads the user's profile via currentProfileProvider so we can
/// greet them by name (mirrors website behavior in DashboardHome).
class HomePlaceholderPage extends ConsumerWidget {
  const HomePlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref.watch(currentProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('WrapUp AI')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting(profile, user?.email),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              profile.when(
                data: (p) => Text(
                  p?.email ?? user?.email ?? '',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                loading: () => Text(
                  'Loading profile…',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                error: (e, _) => Text(
                  'Could not load profile.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.destructive,
                      ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Dashboard placeholder. Real UI arrives in Phase 5.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
              const Spacer(),
              OutlinedButton(
                onPressed: () async {
                  await ref.read(supabaseClientProvider).auth.signOut();
                },
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _greeting(AsyncValue profile, String? fallbackEmail) {
    final name = profile.when(
      data: (p) => (p as dynamic)?.fullName as String?,
      loading: () => null,
      error: (_, _) => null,
    );
    if (name != null && name.isNotEmpty) return 'Welcome back, $name';
    if (fallbackEmail != null && fallbackEmail.isNotEmpty) {
      return 'Welcome back, $fallbackEmail';
    }
    return 'Welcome back';
  }
}
