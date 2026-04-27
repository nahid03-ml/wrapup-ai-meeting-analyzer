import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';

/// Shown after signup. The user must click the confirmation link emailed
/// by Supabase before they can sign in. Mirrors the website's "email not
/// confirmed" UX in src/pages/Login.tsx.
class EmailCheckPage extends ConsumerWidget {
  const EmailCheckPage({super.key, this.email});
  final String? email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AuthScaffold(
      subtitle: 'Confirm your email',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_read_outlined,
            size: 48,
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            email == null
                ? 'We sent a confirmation link to your email. Click the link in the email to activate your account, then come back here to sign in.'
                : 'We sent a confirmation link to $email. Click the link in the email to activate your account, then come back here to sign in.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.xl),
          AuthPrimaryButton(
            label: "I've confirmed — sign in",
            onPressed: () => context.go(AppRoutes.login),
          ),
        ],
      ),
    );
  }
}
