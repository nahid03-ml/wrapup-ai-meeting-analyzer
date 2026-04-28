import 'package:flutter/material.dart';

import '../../../../core/languages/supported_languages.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class LanguagePickerField extends StatelessWidget {
  const LanguagePickerField({
    required this.value,
    required this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final effectiveValue =
        supportedLanguages.any((language) => language.code == value)
        ? value
        : defaultSupportedLanguageCode();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            'Audio language',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        DropdownButtonFormField<String>(
          initialValue: effectiveValue,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select language to continue',
          ),
          items: supportedLanguages
              .map(
                (language) => DropdownMenuItem<String>(
                  value: language.code,
                  child: Text(language.name),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (code) {
                  if (code != null) {
                    onChanged(code);
                  }
                }
              : null,
        ),
      ],
    );
  }
}
