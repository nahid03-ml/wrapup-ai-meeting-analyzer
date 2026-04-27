class BackendException implements Exception {
  const BackendException(this.message, {this.statusCode, this.details});

  final int? statusCode;
  final String message;
  final Object? details;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    final suffix = details == null ? '' : ' Details: $details';
    return '$runtimeType$code: $message$suffix';
  }
}

class UnauthorizedBackendException extends BackendException {
  const UnauthorizedBackendException(
    super.message, {
    super.statusCode,
    super.details,
  });
}

class NotFoundBackendException extends BackendException {
  const NotFoundBackendException(
    super.message, {
    super.statusCode,
    super.details,
  });
}

class ServerBackendException extends BackendException {
  const ServerBackendException(
    super.message, {
    super.statusCode,
    super.details,
  });
}

class UnknownBackendException extends BackendException {
  const UnknownBackendException(
    super.message, {
    super.statusCode,
    super.details,
  });
}
