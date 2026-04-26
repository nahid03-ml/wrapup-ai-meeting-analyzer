/// Domain-level auth errors. The presentation layer switches on these
/// rather than on raw Supabase AuthException codes.
sealed class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

class InvalidCredentialsFailure extends AuthFailure {
  const InvalidCredentialsFailure()
      : super('Invalid email or password.');
}

class EmailNotConfirmedFailure extends AuthFailure {
  const EmailNotConfirmedFailure()
      : super(
          'Please confirm your email before signing in. '
          'Check your inbox for the confirmation link.',
        );
}

class EmailAlreadyExistsFailure extends AuthFailure {
  const EmailAlreadyExistsFailure()
      : super('An account with this email already exists.');
}

class WeakPasswordFailure extends AuthFailure {
  const WeakPasswordFailure()
      : super('Password is too weak. Use at least 8 characters.');
}

class NetworkFailure extends AuthFailure {
  const NetworkFailure()
      : super('Network error. Check your connection and try again.');
}

class UnknownAuthFailure extends AuthFailure {
  const UnknownAuthFailure(super.message);
}
