import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Shared text field for auth forms. Supports password obscuring with
/// an eye toggle that mirrors the website's pattern (lucide Eye/EyeOff).
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.obscureText = false,
    this.allowToggleObscure = false,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.enabled = true,
    this.autofocus = false,
    this.focusNode,
  });

  final TextEditingController controller;
  final String label;
  final String? hintText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final bool obscureText;
  final bool allowToggleObscure;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onFieldSubmitted;
  final bool enabled;
  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  late bool _obscured;

  @override
  void initState() {
    super.initState();
    _obscured = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: _obscured,
            enabled: widget.enabled,
            autofocus: widget.autofocus,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            validator: widget.validator,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            decoration: InputDecoration(
              hintText: widget.hintText,
              suffixIcon: widget.allowToggleObscure
                  ? IconButton(
                      icon: Icon(
                        _obscured ? Icons.visibility : Icons.visibility_off,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscured = !_obscured),
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}
