import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/error_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/presentation/widgets/error_snackbar.dart';
import '../../subscription/application/subscription_provider.dart';
import '../../subscription/data/subscription.dart';
import '../application/profile_provider.dart';
import '../data/profile_repository.dart';
import 'widgets/account_actions_section.dart';
import 'widgets/plan_badge.dart';
import 'widgets/profile_header.dart';
import 'widgets/profile_info_tile.dart';
import 'widgets/profile_section.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _refresh(ref),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.sm,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              const _ProfileHeaderSection(),
              const SizedBox(height: AppSpacing.lg),
              const _PlanSection(),
              const SizedBox(height: AppSpacing.lg),
              const _AccountInformationSection(),
              const SizedBox(height: AppSpacing.lg),
              const _PreferencesSection(),
              const SizedBox(height: AppSpacing.lg),
              _SecuritySection(
                isSigningOut: ref.watch(authControllerProvider).isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _refresh(WidgetRef ref) async {
    ref
      ..invalidate(currentProfileProvider)
      ..invalidate(subscriptionProvider);

    await Future.wait([
      _readSafely(() => ref.read(currentProfileProvider.future)),
      _readSafely(() => ref.read(subscriptionProvider.future)),
    ]);
  }
}

class _ProfileHeaderSection extends ConsumerWidget {
  const _ProfileHeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profile = ref
        .watch(currentProfileProvider)
        .whenOrNull(data: (profile) => profile);
    final subscription = ref
        .watch(subscriptionProvider)
        .whenOrNull(data: (subscription) => subscription);
    final email = _emailFor(user: user, profile: profile);
    final displayName = _displayName(profile: profile, email: email);
    final planTier = subscription?.planTier ?? PlanTier.free;

    return ProfileHeader(
      displayName: displayName,
      email: email ?? 'No email available',
      initials: _initials(displayName: displayName, email: email),
      planTier: planTier,
    );
  }
}

class _PlanSection extends ConsumerWidget {
  const _PlanSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionValue = ref.watch(subscriptionProvider);

    return subscriptionValue.when(
      data: (subscription) => _PlanSectionContent(subscription: subscription),
      loading: () =>
          const _PlanSectionContent(subscription: null, isLoading: true),
      error: (error, stackTrace) => ProfileSection(
        icon: Icons.workspace_premium_outlined,
        title: 'Plan',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PlanSummary(subscription: null),
            const SizedBox(height: AppSpacing.lg),
            ErrorView(
              title: 'Could not load plan',
              message: error.toString(),
              onRetry: () => ref.invalidate(subscriptionProvider),
            ),
            const SizedBox(height: AppSpacing.md),
            _ManagePlanButton(onPressed: () => _showManagePlanSoon(context)),
          ],
        ),
      ),
    );
  }
}

class _PlanSectionContent extends StatelessWidget {
  const _PlanSectionContent({
    required this.subscription,
    this.isLoading = false,
  });

  final Subscription? subscription;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ProfileSection(
      icon: Icons.workspace_premium_outlined,
      title: 'Plan',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _PlanSummary(subscription: subscription, isLoading: isLoading),
          const SizedBox(height: AppSpacing.md),
          _ManagePlanButton(onPressed: () => _showManagePlanSoon(context)),
        ],
      ),
    );
  }
}

class _PlanSummary extends StatelessWidget {
  const _PlanSummary({required this.subscription, this.isLoading = false});

  final Subscription? subscription;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final tier = subscription?.planTier ?? PlanTier.free;
    final paid = tier != PlanTier.free;
    final status = subscription?.status.trim();
    final periodEnd = subscription?.currentPeriodEnd;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated.withValues(alpha: 0.54),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.72)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isLoading
                          ? 'Checking plan...'
                          : '${planTierLabel(tier)} plan',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      planTierDescription(tier),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              PlanBadge(planTier: tier),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ProfileInfoTile(
            icon: paid ? Icons.check_circle_outline : Icons.info_outline,
            label: 'Status',
            value: isLoading ? 'Checking' : _statusLabel(status),
          ),
          if (periodEnd != null) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileInfoTile(
              icon: Icons.event_outlined,
              label: 'Current period ends',
              value: DateFormat.yMMMd().format(periodEnd.toLocal()),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagePlanButton extends StatelessWidget {
  const _ManagePlanButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.credit_card_outlined),
      label: const Text('Manage plan'),
    );
  }
}

class _AccountInformationSection extends ConsumerWidget {
  const _AccountInformationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final profileValue = ref.watch(currentProfileProvider);
    final profile = profileValue.whenOrNull(data: (profile) => profile);
    final email = _emailFor(user: user, profile: profile) ?? 'Not available';
    final displayName = _displayName(profile: profile, email: email);

    return ProfileSection(
      icon: Icons.account_circle_outlined,
      title: 'Account information',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileInfoTile(
            icon: Icons.email_outlined,
            label: 'Email',
            value: email,
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileInfoTile(
            icon: Icons.badge_outlined,
            label: 'User ID',
            value: _shortId(user?.id ?? profile?.id),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileInfoTile(
            icon: Icons.calendar_today_outlined,
            label: 'Account created',
            value: _formatAuthDate(user?.createdAt),
          ),
          const SizedBox(height: AppSpacing.sm),
          ProfileInfoTile(
            icon: Icons.person_outline,
            label: 'Profile name',
            value: displayName,
          ),
          if (profile?.role?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.sm),
            ProfileInfoTile(
              icon: Icons.admin_panel_settings_outlined,
              label: 'Role',
              value: profile!.role!.trim(),
            ),
          ],
          profileValue.when(
            data: (_) => const SizedBox.shrink(),
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: LinearProgressIndicator(minHeight: 2),
            ),
            error: (error, stackTrace) => Padding(
              padding: const EdgeInsets.only(top: AppSpacing.md),
              child: ErrorView(
                title: 'Could not load profile details',
                message: error.toString(),
                onRetry: () => ref.invalidate(currentProfileProvider),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection();

  @override
  Widget build(BuildContext context) {
    return const ProfileSection(
      icon: Icons.tune_outlined,
      title: 'Preferences',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ProfileInfoTile(
            icon: Icons.language_outlined,
            label: 'Language',
            value: 'Auto detect',
          ),
          SizedBox(height: AppSpacing.sm),
          ProfileInfoTile(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            value: 'Coming soon',
          ),
          SizedBox(height: AppSpacing.sm),
          ProfileInfoTile(
            icon: Icons.file_download_outlined,
            label: 'Data export',
            value: 'Coming soon',
          ),
        ],
      ),
    );
  }
}

class _SecuritySection extends ConsumerWidget {
  const _SecuritySection({required this.isSigningOut});

  final bool isSigningOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AccountActionsSection(
      isSigningOut: isSigningOut,
      onSignOut: () => _signOut(context, ref),
    );
  }
}

Future<void> _signOut(BuildContext context, WidgetRef ref) async {
  await ref.read(authControllerProvider.notifier).signOut();
  final state = ref.read(authControllerProvider);
  if (!context.mounted || !state.hasError) return;
  showAuthErrorSnackBar(context, state.error!);
}

Future<void> _readSafely<T>(Future<T> Function() read) async {
  try {
    await read();
  } catch (_) {
    // Each profile section owns its loading/error fallback.
  }
}

void _showManagePlanSoon(BuildContext context) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    const SnackBar(content: Text('Billing management is coming in Phase 7.')),
  );
}

String? _emailFor({required User? user, required UserProfile? profile}) {
  final profileEmail = profile?.email.trim();
  if (profileEmail != null && profileEmail.isNotEmpty) return profileEmail;
  final userEmail = user?.email?.trim();
  if (userEmail != null && userEmail.isNotEmpty) return userEmail;
  return null;
}

String _displayName({required UserProfile? profile, required String? email}) {
  final name = profile?.fullName?.trim();
  if (name != null && name.isNotEmpty) return name;

  final rawEmail = email?.trim();
  if (rawEmail != null && rawEmail.isNotEmpty) {
    final local = rawEmail.split('@').first.trim();
    if (local.isNotEmpty) return local;
  }

  return 'User';
}

String _initials({required String displayName, required String? email}) {
  final nameParts = displayName
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (nameParts.isNotEmpty && displayName != 'User') {
    return nameParts
        .take(2)
        .map((part) => part.characters.first.toUpperCase())
        .join();
  }

  final localEmail = email?.split('@').first.trim();
  if (localEmail != null && localEmail.isNotEmpty) {
    return localEmail.characters.first.toUpperCase();
  }

  return 'U';
}

String _shortId(String? id) {
  final value = id?.trim();
  if (value == null || value.isEmpty) return 'Not available';
  if (value.length <= 12) return value;
  return '${value.substring(0, 8)}...${value.substring(value.length - 4)}';
}

String _formatAuthDate(String? value) {
  final raw = value?.trim();
  if (raw == null || raw.isEmpty) return 'Not available';
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return 'Not available';
  return DateFormat.yMMMd().format(parsed.toLocal());
}

String _statusLabel(String? status) {
  final value = status?.trim();
  if (value == null || value.isEmpty) return 'Free';
  return value
      .split('_')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}
