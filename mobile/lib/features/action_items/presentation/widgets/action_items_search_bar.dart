import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ActionItemsSearchBar extends StatelessWidget {
  const ActionItemsSearchBar({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final hasText = controller.text.trim().isNotEmpty;
          return TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: 'Search tasks, assignees, meetings...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              suffixIcon: hasText
                  ? IconButton(
                      tooltip: 'Clear search',
                      onPressed: onClear,
                      icon: const Icon(Icons.close),
                    )
                  : null,
              filled: true,
              fillColor: AppColors.surface.withValues(alpha: 0.72),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: BorderSide(
                  color: AppColors.border.withValues(alpha: 0.72),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1.4,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
