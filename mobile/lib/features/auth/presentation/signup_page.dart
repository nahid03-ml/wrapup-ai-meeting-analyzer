import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import '../data/password_rules.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/error_snackbar.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({super.key});

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _confirmCtl = TextEditingController();
  final _nameFocus = FocusNode();

  String _password = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _nameFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _nameCtl.dispose();
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _confirmCtl.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!isPasswordValid(_password)) return;
    FocusScope.of(context).unfocus();

    final email = _emailCtl.text.trim();
    final controller = ref.read(authControllerProvider.notifier);

    await controller.signUp(
      email: email,
      password: _passwordCtl.text,
      fullName: _nameCtl.text.trim(),
    );
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      showAuthErrorSnackBar(context, state.error!);
      return;
    }
    // Email confirmation required (mailer_autoconfirm: false on the project).
    context.go(
      AppRoutes.emailCheck,
      extra: email,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;
    final rules = evaluatePasswordRules(_password);

    return AuthScaffold(
      subtitle: 'Create your WrapUp AI account',
      showBack: true,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _nameCtl,
              focusNode: _nameFocus,
              label: 'Full name',
              hintText: 'Jane Doe',
              keyboardType: TextInputType.name,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.name],
              enabled: !isLoading,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
            ),
            AuthTextField(
              controller: _emailCtl,
              label: 'Email',
              hintText: 'you@example.com',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              enabled: !isLoading,
              validator: (v) {
                final value = (v ?? '').trim();
                if (value.isEmpty) return 'Enter your email';
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Enter a valid email';
                }
                return null;
              },
            ),
            AuthTextField(
              controller: _passwordCtl,
              label: 'Password',
              hintText: 'Choose a strong password',
              obscureText: true,
              allowToggleObscure: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !isLoading,
              onChanged: (v) => setState(() => _password = v),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter a password';
                if (!isPasswordValid(v)) return 'Password does not meet all requirements';
                return null;
              },
            ),
            _PasswordRulesList(rules: rules),
            const SizedBox(height: AppSpacing.lg),
            AuthTextField(
              controller: _confirmCtl,
              label: 'Confirm password',
              hintText: 'Re-enter your password',
              obscureText: true,
              allowToggleObscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              enabled: !isLoading,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Re-enter your password';
                if (v != _passwordCtl.text) return 'Passwords do not match';
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),
            AuthPrimaryButton(
              label: 'Create account',
              onPressed: _submit,
              isLoading: isLoading,
            ),
            // Google sign-in button intentionally disabled — see login_page.
            //
            // const SizedBox(height: AppSpacing.lg),
            // GoogleSignInButton(
            //   isLoading: isLoading,
            //   onPressed: () => ref
            //       .read(authControllerProvider.notifier)
            //       .signInWithGoogle(),
            // ),
            const SizedBox(height: AppSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account?',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                TextButton(
                  onPressed: isLoading ? null : () => context.pop(),
                  child: const Text('Sign in'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordRulesList extends StatelessWidget {
  const _PasswordRulesList({required this.rules});
  final List<PasswordRule> rules;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rules.map((rule) {
          final color = rule.met ? AppColors.success : AppColors.destructive;
          final icon = rule.met ? Icons.check_circle : Icons.cancel;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(icon, size: 14, color: color),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    rule.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: color,
                        ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
