final class TheFaithAppEnvironment {
  TheFaithAppEnvironment._();

  static final Uri apiBaseUrl = parseTheFaithAppEnvironmentUri(
    const String.fromEnvironment(
      'TFA_API_BASE_URL',
      defaultValue: 'https://api.thefaithapp.com',
    ),
    name: 'TFA_API_BASE_URL',
  );
  static final Uri hostedAuthBaseUrl = parseTheFaithAppEnvironmentUri(
    const String.fromEnvironment(
      'TFA_HOSTED_AUTH_BASE_URL',
      defaultValue: 'https://auth.thefaithapp.com',
    ),
    name: 'TFA_HOSTED_AUTH_BASE_URL',
  );
}

/// Parses a build-time SDK origin while preventing credentials, paths, and
/// plaintext traffic to non-loopback hosts.
///
/// This remains internal to the package's supported public API. It is named so
/// package tests can exercise the security boundary directly.
Uri parseTheFaithAppEnvironmentUri(String value, {required String name}) {
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      !uri.hasScheme ||
      uri.host.isEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    throw ArgumentError.value(value, name, 'Must be an origin URL.');
  }

  final scheme = uri.scheme.toLowerCase();
  final host = uri.host.toLowerCase();
  final isLoopback =
      host == 'localhost' || host == '127.0.0.1' || host == '::1';
  if (scheme != 'https' && !(scheme == 'http' && isLoopback)) {
    throw ArgumentError.value(
      value,
      name,
      'Must use HTTPS, except for localhost development.',
    );
  }

  return uri.replace(
    scheme: scheme,
    host: host,
    path: '',
    query: null,
    fragment: null,
  );
}
