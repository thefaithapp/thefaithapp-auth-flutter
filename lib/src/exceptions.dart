/// Stable error categories returned by [TheFaithAuthException].
enum TheFaithAuthErrorCode {
  configuration,
  network,
  cancelled,
  server,
  invalidResponse,
  stateMismatch,
  callbackMismatch,
  missingAuthorizationCode,
  sessionStorage,
  notAuthenticated,
  signInInProgress,
  unauthorizedHost,
}

/// An expected configuration, authentication, storage, or API failure.
final class TheFaithAuthException implements Exception {
  const TheFaithAuthException(
    this.code,
    this.message, {
    this.statusCode,
    this.cause,
  });

  final TheFaithAuthErrorCode code;
  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'TheFaithAuthException.${code.name}$status: $message';
  }
}
