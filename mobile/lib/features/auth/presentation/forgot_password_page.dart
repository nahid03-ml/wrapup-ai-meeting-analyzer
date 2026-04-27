import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/auth_controller.dart';
import 'widgets/auth_primary_button.dart';
import 'widgets/auth_scaffold.dart';
import 'widgets/auth_text_field.dart';
import 'widgets/error_snackbar.dart';

class ForgotPasswordPage extends ConsumerStatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  ConsumerState<ForgotPasswordPage> createState() =>
      _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends ConsumerState<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtl = TextEditingController();
  final _emailFocus = FocusNode();
  bool _sent = false;

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
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .sendPasswordResetEmail(_emailCtl.text.trim());
    final state = ref.read(authControllerProvider);
    if (!mounted) return;
    if (state.hasError) {
      showAuthErrorSnackBar(context, state.error!);
      return;
    }
    setState(() => _sent = true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.isLoading;

    return AuthScaffold(
      subtitle: _sent
          ? 'Check your inbox'
          : 'Enter your email to receive a reset link',
      showBack: true,
      child: _sent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.mark_email_read_outlined,
                  size: 48,
                  color: AppColors.primary,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  "We sent a password reset link to ${_emailCtl.text.trim()}.",
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xl),
                AuthPrimaryButton(
                  label: 'Back to sign in',
                  onPressed: () => context.pop(),
                ),
              ],
            )
          : Form(
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
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.email],
                    enabled: !isLoading,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Enter your email';
                      if (!value.contains('@') || !value.contains('.')) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AuthPrimaryButton(
                    label: 'Send reset link',
                    onPressed: _submit,
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
    );
  }
}
