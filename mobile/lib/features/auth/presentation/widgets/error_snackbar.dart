import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Helper for surfacing AuthFailure messages from the controller.
/// Mirrors the website's toast pattern (sonner / useToast variant=destructive).
void showAuthErrorSnackBar(BuildContext context, Object error) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      backgroundColor: AppColors.destructive,
      content: Text(
        error.toString(),
        style: const TextStyle(color: Colors.white),
      ),
    ),
  );
}

void showAuthInfoSnackBar(BuildContext context, String message) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
    ),
  );
}
