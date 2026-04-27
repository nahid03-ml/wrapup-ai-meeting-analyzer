import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'profile_section.dart';

class AccountActionsSection extends StatelessWidget {
  const AccountActionsSection({
    required this.onSignOut,
    this.isSigningOut = false,
    super.key,
  });

  final VoidCallback onSignOut;
  final bool isSigningOut;

  @override
  Widget build(BuildContext context) {
    return ProfileSection(
      icon: Icons.security_outlined,
      title: 'Security',
      child: OutlinedButton.icon(
        onPressed: isSigningOut ? null : onSignOut,
        icon: isSigningOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout),
        label: Text(isSigningOut ? 'Signing out...' : 'Sign out'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.destructive,
          side: BorderSide(color: AppColors.destructive.withValues(alpha: 0.5)),
          minimumSize: const Size.fromHeight(48),
        ),
      ),
    );
  }
}
