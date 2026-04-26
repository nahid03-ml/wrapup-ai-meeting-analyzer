import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Placeholder login page. Real auth UI ships in Phase 2.
class LoginPlaceholderPage extends ConsumerWidget {
  const LoginPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (rect) =>
                      AppColors.brandGradient.createShader(rect),
                  child: Text(
                    'WrapUp AI',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Login (Phase 2 placeholder)',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: null,
                  child: const Text('Auth UI coming next phase'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
