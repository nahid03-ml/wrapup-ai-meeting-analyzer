import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/error_snackbar.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _emailFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _emailFocus.requestFocus();
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  }

  @override
  void dispose() {
    _emailCtl.dispose();
    _passwordCtl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).signIn(
          email: _emailCtl.text.trim(),
          password: _passwordCtl.text,
        );
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      showAuthErrorSnackBar(context, state.error!);
    }
    // On success the router redirect (auth guard) takes us to /dashboard.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;

    return AuthScaffold(
      subtitle: 'Sign in to your account',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _emailCtl,
              focusNode: _emailFocus,
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
              hintText: 'Your password',
              obscureText: true,
              allowToggleObscure: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              enabled: !isLoading,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: isLoading
                    ? null
                    : () => context.push(AppRoutes.forgotPassword),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            AuthPrimaryButton(
              label: 'Sign in',
              onPressed: _submit,
              isLoading: isLoading,
            ),
            // Google sign-in button is intentionally disabled until the
            // Supabase project's redirect allow-list includes
            // io.wrapupai.app://login-callback. Uncomment when ready.
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
                  "Don't have an account?",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                ),
                TextButton(
                  onPressed: isLoading
                      ? null
                      : () => context.push(AppRoutes.signup),
                  child: const Text('Sign up'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
