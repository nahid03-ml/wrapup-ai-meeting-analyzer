/// One password requirement rule. UI renders the [label] in green if [met],
/// red if not, mirroring the website's live checklist on signup.
class PasswordRule {
  const PasswordRule({required this.label, required this.met});
  final String label;
  final bool met;
}

/// Evaluates a password against the same 4 rules the website enforces
/// at SignUp.tsx:216-225 and lib/auth.ts:87-94.
List<PasswordRule> evaluatePasswordRules(String password) {
  return [
    PasswordRule(
      label: 'At least 8 characters',
      met: password.length >= 8,
    ),
    PasswordRule(
      label: 'Must contain a number',
      met: RegExp(r'[0-9]').hasMatch(password),
    ),
    PasswordRule(
      label: 'Must contain an uppercase letter',
      met: RegExp(r'[A-Z]').hasMatch(password),
    ),
    PasswordRule(
      label: 'Must contain a special character',
      met: RegExp(r'[^a-zA-Z0-9]').hasMatch(password),
    ),
  ];
}

/// Returns true if every rule is met. Use as the gate for the
/// signup submit button.
bool isPasswordValid(String password) {
  return evaluatePasswordRules(password).every((r) => r.met);
}
